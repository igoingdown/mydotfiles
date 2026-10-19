"""Publish frozen numeric reports and resume delivery to the pinned user.

CLI responses stay in memory. Only validated document links, message receipts,
and generated-artifact digests are saved; error bodies are never forwarded.
"""

from __future__ import annotations

from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import time
from urllib.parse import urlsplit
import uuid
import xml.etree.ElementTree as ET

from .common import ReportError, atomic_json, cli_json, read_json


FILES = ("packet.json", "report.xml", "summary.txt", "counts.png", "durations.png")
IMAGES = ("counts.png", "durations.png")
PARTS = ("summary", "counts", "durations")
RETRY_SECONDS = 55 * 60
_DOC_ID = re.compile(r"[A-Za-z0-9]{1,128}\Z")
_MESSAGE_ID = re.compile(r"om_[A-Za-z0-9]+\Z")
_CHAT_ID = re.compile(r"oc_[A-Za-z0-9]+\Z")
_REPORT_KEY = re.compile(r"(?:daily-\d{8}|halfday-\d{8}-(?:10|22))\Z")


def _fail(category):
    raise ReportError(category) from None


def _call(config, args, directory=None, category="DeliveryCliFailure"):
    return cli_json(
        [config["lark_cli"], *args], cwd=directory, timeout=120,
        error_category=category,
    )


def _data(response, category):
    if not isinstance(response, dict):
        _fail(category)
    if response.get("ok") is False:
        _fail(category)
    if "code" in response and (type(response["code"]) is not int or response["code"] != 0):
        _fail(category)
    if response.get("ok") is not True and response.get("code") != 0:
        _fail(category)
    data = response.get("data", response)
    if not isinstance(data, dict):
        _fail(category)
    return data


def _pin(config):
    receiver = config.get("receiver")
    if not isinstance(receiver, dict):
        _fail("IdentityMismatch")
    app_id, open_id = receiver.get("app_id"), receiver.get("open_id")
    if not isinstance(app_id, str) or not re.fullmatch(r"cli_[A-Za-z0-9]+", app_id):
        _fail("IdentityMismatch")
    if not isinstance(open_id, str) or not re.fullmatch(r"ou_[A-Za-z0-9]+", open_id):
        _fail("IdentityMismatch")
    return {"app_id": app_id, "open_id": open_id}


def verify_identity(config):
    """Verify the authenticated user, never the bot open ID, against the pin."""
    pin = _pin(config)
    response = _call(config, ["auth", "status", "--verify", "--json"], category="IdentityCheckFailed")
    data = response.get("data", response)
    if not isinstance(data, dict) or data.get("verified") is not True:
        _fail("IdentityCheckFailed")
    identities = data.get("identities")
    user = identities.get("user") if isinstance(identities, dict) else None
    if not isinstance(user, dict):
        _fail("IdentityMismatch")
    if data.get("appId") != pin["app_id"] or user.get("openId") != pin["open_id"]:
        _fail("IdentityMismatch")
    if user.get("status") != "ready" or user.get("tokenStatus") != "valid":
        _fail("IdentityCheckFailed")
    if response.get("ok") is False or ("code" in response and (type(response["code"]) is not int or response["code"] != 0)):
        _fail("IdentityCheckFailed")
    return pin


def _artifact(directory, name):
    path = directory / name
    try:
        valid = not path.is_symlink() and path.is_file() and path.stat().st_size <= 20 * 1024 * 1024
    except OSError:
        valid = False
    if not valid:
        _fail("PackageInvalid")
    return path


def _read_artifact(directory, name, *, text=False):
    path = _artifact(directory, name)
    try:
        return path.read_text(encoding="utf-8") if text else path.read_bytes()
    except (OSError, UnicodeError):
        _fail("PackageInvalid")


def _write_text(path, value):
    try:
        fd, temp = tempfile.mkstemp(prefix=".summary-", dir=path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as stream:
                stream.write(value)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temp, path)
        finally:
            if os.path.exists(temp):
                os.unlink(temp)
    except OSError:
        _fail("StateWriteFailure")


def _digest_files(directory):
    return {name: hashlib.sha256(_read_artifact(directory, name)).hexdigest() for name in FILES}


def _package_digest(files):
    payload = json.dumps(files, sort_keys=True, separators=(",", ":")).encode("ascii")
    return hashlib.sha256(payload).hexdigest()


def _manifest(directory, rendered):
    if rendered.get("xml_name") != "report.xml" or rendered.get("images") != list(IMAGES):
        _fail("PackageInvalid")
    summary = rendered.get("summary")
    if not isinstance(summary, str) or not summary.strip() or len(summary) > 12000:
        _fail("PackageInvalid")
    packet = read_json(_artifact(directory, "packet.json"))
    report_key = packet.get("report_key") if isinstance(packet, dict) else None
    if not isinstance(report_key, str) or not _REPORT_KEY.fullmatch(report_key):
        _fail("PackageInvalid")
    path = directory / "package-manifest.json"
    if path.exists():
        manifest = read_json(path)
        if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
            _fail("PackageChanged")
        if _read_artifact(directory, "summary.txt", text=True) != summary:
            _fail("PackageChanged")
        files = _digest_files(directory)
        if manifest.get("report_key") != report_key or manifest.get("files") != files:
            _fail("PackageChanged")
        if manifest.get("package_sha256") != _package_digest(files):
            _fail("PackageChanged")
        return manifest
    _write_text(directory / "summary.txt", summary)
    files = _digest_files(directory)
    manifest = {"schema_version": 1, "report_key": report_key, "files": files,
                "package_sha256": _package_digest(files)}
    atomic_json(path, manifest)
    return manifest


def _check_binding(state, manifest, pin):
    if not isinstance(state, dict) or state.get("schema_version") != 1:
        _fail("DeliveryStateInvalid")
    if state.get("report_key") != manifest["report_key"] or state.get("package_sha256") != manifest["package_sha256"]:
        _fail("PackageChanged")
    if state.get("receiver") != pin:
        _fail("IdentityMismatch")


def _valid_document(document):
    doc_id, url = document.get("document_id"), document.get("url")
    if not isinstance(doc_id, str) or not _DOC_ID.fullmatch(doc_id) or not isinstance(url, str):
        _fail("DocumentResponseInvalid")
    try:
        parsed = urlsplit(url)
        valid = (parsed.scheme == "https" and parsed.hostname is not None
                 and parsed.hostname.endswith((".feishu.cn", ".larksuite.com"))
                 and not parsed.username and not parsed.password and parsed.port is None
                 and not parsed.query and not parsed.fragment and parsed.path == "/docx/" + doc_id)
    except ValueError:
        valid = False
    if not valid:
        _fail("DocumentResponseInvalid")
    return {"document_id": doc_id, "url": url}


def _xml(value):
    if not isinstance(value, str) or len(value) > 2_000_000 or "<!" in value:
        _fail("DocumentReadbackFailed")
    try:
        return ET.fromstring("<report>" + value + "</report>")
    except (ET.ParseError, ValueError):
        _fail("DocumentReadbackFailed")


def _fetch(config, directory, doc_id):
    response = _call(config, ["docs", "+fetch", "--doc", doc_id, "--detail", "full", "--as", "user", "--format", "json"], directory)
    data = _data(response, "DocumentReadbackFailed")
    doc = data.get("document")
    if not isinstance(doc, dict) or doc.get("document_id") != doc_id:
        _fail("DocumentReadbackFailed")
    return _xml(doc.get("content"))


def _images(root):
    images = list(root.iter("img"))
    if any(not (image.get("token") or image.get("src")) for image in images):
        _fail("DocumentReadbackFailed")
    return images


def _compact_text(element):
    return re.sub(r"\s+", "", "".join(element.itertext()))


def _table_rows(table):
    # Feishu may normalize thead/tbody and th/td. Preserve row and cell
    # boundaries so redistributed digits cannot pass concatenated-text checks.
    rows = []
    for row in table.iter("tr"):
        cells = tuple(_compact_text(cell) for cell in row if cell.tag in ("td", "th"))
        if not cells:
            _fail("DocumentTableContentMismatch")
        rows.append(cells)
    return tuple(rows)


def _check_document_content(root, expected, image_count):
    if len(_images(root)) != image_count:
        _fail("DocumentReadbackFailed")
    expected_tables, tables = list(expected.iter("table")), list(root.iter("table"))
    if not expected_tables or len(tables) != len(expected_tables):
        _fail("DocumentReadbackFailed")
    for table, expected_table in zip(tables, expected_tables):
        if _table_rows(table) != _table_rows(expected_table):
            _fail("DocumentTableContentMismatch")
        columns = table.findall("./colgroup/col")
        total = 0
        for col in columns:
            width, span = col.get("width", ""), col.get("span", "1")
            if not width.isdecimal() or not span.isdecimal() or int(span) < 1:
                _fail("DocumentTableWidthFailed")
            total += int(width) * int(span)
        if not columns or total != 820:
            _fail("DocumentTableWidthFailed")
    if not _compact_text(expected) or _compact_text(expected) != _compact_text(root):
        _fail("DocumentContentMismatch")
    if list(root.iter("pre")) or list(root.iter("code")):
        # The numeric report contract has no code or untranslated examples.
        _fail("DocumentContentMismatch")


def _check_wrap(config, directory, doc_id):
    args = [sys.executable, config["code_wrap_checker"], doc_id]
    try:
        result = cli_json(args, cwd=directory, timeout=180, error_category="DocumentWrapCheckFailed")
        if result.get("verified") is True:
            return
    except ReportError:
        pass
    result = cli_json([*args, "--fix"], cwd=directory, timeout=180, error_category="DocumentWrapCheckFailed")
    if result.get("verified") is not True:
        _fail("DocumentWrapCheckFailed")
    result = cli_json(args, cwd=directory, timeout=180, error_category="DocumentWrapCheckFailed")
    if result.get("verified") is not True:
        _fail("DocumentWrapCheckFailed")


def publish_document(config, directory, rendered):
    """Freeze once, publish once, and verify the complete document before IM."""
    directory = Path(directory)
    manifest = _manifest(directory, rendered)
    pin = verify_identity(config)
    expected = _xml(_read_artifact(directory, "report.xml", text=True))
    if list(expected.iter("img")) or list(expected.iter("pre")) or list(expected.iter("code")):
        _fail("PackageInvalid")
    path = directory / "document.json"
    if path.exists():
        state = read_json(path)
        _check_binding(state, manifest, pin)
        if state.get("status") == "creating":
            _fail("DocumentPendingReview")
        doc = _valid_document(state)
    else:
        state = {"schema_version": 1, "report_key": manifest["report_key"],
                 "package_sha256": manifest["package_sha256"], "receiver": pin,
                 "status": "creating", "inserted_images": 0, "verified": False}
        atomic_json(path, state)
        response = _call(config, ["docs", "+create", "--content", "@report.xml", "--as", "user", "--format", "json"], directory)
        data = _data(response, "DocumentResponseInvalid")
        raw_document = data.get("document")
        if not isinstance(raw_document, dict):
            _fail("DocumentResponseInvalid")
        doc = _valid_document(raw_document)
        state.update(doc, status="created")
        atomic_json(path, state)
    count = state.get("inserted_images")
    if type(count) is not int or not 0 <= count <= 2:
        _fail("DeliveryStateInvalid")
    # Any failed fresh verification must revoke the previous local approval.
    state["verified"] = False
    atomic_json(path, state)
    root = _fetch(config, directory, doc["document_id"])
    if state.get("status") == "inserting":
        if count >= 2 or len(_images(root)) != count + 1:
            _fail("DocumentPendingReview")
        # This dedicated document starts with no media. A completed extra image
        # after a crash is the only permitted recovery; absence stays uncertain.
        count += 1
        state.update(status="created", inserted_images=count)
        atomic_json(path, state)
    elif state.get("status") not in ("created", "verified"):
        _fail("DeliveryStateInvalid")
    _check_document_content(root, expected, count)
    while count < 2:
        state.update(status="inserting", verified=False)
        atomic_json(path, state)
        response = _call(config, ["docs", "+media-insert", "--doc", doc["document_id"],
                                  "--file", "./" + IMAGES[count], "--type", "image", "--width", "820",
                                  "--as", "user", "--format", "json"], directory)
        _data(response, "DocumentImageInsertFailed")
        count += 1
        state.update(status="created", inserted_images=count)
        atomic_json(path, state)
    _check_wrap(config, directory, doc["document_id"])
    root = _fetch(config, directory, doc["document_id"])
    _check_document_content(root, expected, 2)
    state.update(status="verified", verified=True)
    atomic_json(path, state)
    return {**doc, "verified": True}


def _receipt_time(value):
    """Validate CLI time metadata without guessing a timezone or using it to retry.

    CLI send formats local time to seconds; message readback formats to minutes.
    Raw API epoch values remain accepted for compatibility with JSON adapters.
    """
    if type(value) not in (str, int):
        _fail("DeliverySendUnconfirmed")
    text = str(value)
    if re.fullmatch(r"[0-9]{1,16}", text) and int(text) > 0:
        return text
    for pattern, fmt in (
        (r"[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}", "%Y-%m-%d %H:%M"),
        (r"[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}", "%Y-%m-%d %H:%M:%S"),
    ):
        if re.fullmatch(pattern, text):
            try:
                datetime.strptime(text, fmt)
            except ValueError:
                _fail("DeliverySendUnconfirmed")
            return text
    _fail("DeliverySendUnconfirmed")


def _receipt(response):
    data = _data(response, "DeliverySendUnconfirmed")
    message_id, chat_id, created = data.get("message_id"), data.get("chat_id"), data.get("create_time")
    if not isinstance(message_id, str) or not _MESSAGE_ID.fullmatch(message_id):
        _fail("DeliverySendUnconfirmed")
    if not isinstance(chat_id, str) or not _CHAT_ID.fullmatch(chat_id):
        _fail("DeliverySendUnconfirmed")
    return {"message_id": message_id, "chat_id": chat_id, "create_time": _receipt_time(created)}


def _new_outbox(manifest, pin, document):
    state = {"schema_version": 1, "report_key": manifest["report_key"],
             "package_sha256": manifest["package_sha256"], "receiver": pin,
             "document_id": document["document_id"], "url": document["url"],
             "complete": False, "verified": False, "parts": []}
    for name in PARTS:
        payload = ":".join((manifest["report_key"], manifest["package_sha256"], pin["app_id"], pin["open_id"], name))
        state["parts"].append({"name": name, "status": "ready", "idempotency_key": str(uuid.uuid5(uuid.NAMESPACE_URL, payload)), "verified": False})
    return state


def _check_outbox(state, manifest, pin, document):
    _check_binding(state, manifest, pin)
    if state.get("document_id") != document["document_id"] or state.get("url") != document["url"]:
        _fail("PackageChanged")
    expected = _new_outbox(manifest, pin, document)["parts"]
    parts = state.get("parts")
    if not isinstance(parts, list) or len(parts) != 3:
        _fail("DeliveryStateInvalid")
    for part, reference in zip(parts, expected):
        if not isinstance(part, dict) or any(part.get(key) != reference[key] for key in ("name", "idempotency_key")):
            _fail("DeliveryStateInvalid")
        if part.get("status") not in ("ready", "sending", "sent"):
            _fail("DeliveryStateInvalid")
        if part["status"] != "ready":
            first = part.get("first_attempt_at")
            if type(first) not in (float, int) or not 0 < first < float("inf"):
                _fail("DeliveryStateInvalid")
        if part["status"] == "sent":
            _receipt({"ok": True, "data": part})


def _verify_messages(config, directory, state):
    ids = [part["message_id"] for part in state["parts"]]
    response = _call(config, ["im", "+messages-mget", "--message-ids", ",".join(ids),
                              "--no-reactions", "--as", "bot", "--format", "json"], directory)
    data = _data(response, "DeliveryReadbackFailed")
    messages = data.get("messages")
    if not isinstance(messages, list) or len(messages) != 3:
        _fail("DeliveryReadbackFailed")
    by_id = {}
    for message in messages:
        if not isinstance(message, dict) or message.get("message_id") not in ids:
            _fail("DeliveryReadbackFailed")
        by_id[message["message_id"]] = message
    if len(by_id) != 3:
        _fail("DeliveryReadbackFailed")
    chat_ids = {part["chat_id"] for part in state["parts"]}
    if len(chat_ids) != 1:
        _fail("DeliveryChatMismatch")
    for part, kind in zip(state["parts"], ("post", "image", "image")):
        message = by_id[part["message_id"]]
        if message.get("msg_type") != kind or message.get("chat_id") != part["chat_id"] or message.get("deleted") is True:
            _fail("DeliveryReadbackFailed")
        part["verified"] = True


def deliver_self(config, directory, rendered, document):
    """Send exactly three pinned-user parts and verify their own message IDs."""
    directory = Path(directory)
    manifest = _manifest(directory, rendered)
    pin = verify_identity(config)
    doc = _valid_document(document)
    doc_state = read_json(directory / "document.json")
    _check_binding(doc_state, manifest, pin)
    if document.get("verified") is not True or doc_state.get("verified") is not True or doc_state.get("status") != "verified":
        _fail("DocumentNotVerified")
    if any(doc_state.get(key) != doc[key] for key in ("document_id", "url")):
        _fail("DocumentNotVerified")
    path = directory / "outbox.json"
    state = read_json(path) if path.exists() else _new_outbox(manifest, pin, doc)
    _check_outbox(state, manifest, pin, doc)
    atomic_json(path, state)
    for part in state["parts"]:
        if part["status"] == "sent":
            continue
        now = time.time()
        if part["status"] == "sending":
            age = now - part["first_attempt_at"]
            if age < 0 or age >= RETRY_SECONDS:
                _fail("DeliveryPendingReview")
        else:
            part["first_attempt_at"] = now
        # Persist before the network call. A crash or malformed response leaves
        # sending with the original timestamp and the original idempotency key.
        part.update(status="sending", verified=False)
        state.update(complete=False, verified=False)
        atomic_json(path, state)
        args = ["im", "+messages-send", "--user-id", pin["open_id"], "--as", "bot",
                "--idempotency-key", part["idempotency_key"], "--format", "json"]
        if part["name"] == "summary":
            args += ["--markdown", rendered["summary"] +
                     "\n\n口径：MySQL 为当前节点全部账号慢日志；PostgreSQL 次数含后台、业务耗时待核。缺失不代表零。" +
                     "\n\n[查看完整日报](" + doc["url"] + ")"]
        else:
            args += ["--image", "./" + ("counts.png" if part["name"] == "counts" else "durations.png")]
        receipt = _receipt(_call(config, args, directory, "DeliverySendUnconfirmed"))
        part.update(receipt, status="sent")
        atomic_json(path, state)
        if len({item["chat_id"] for item in state["parts"] if item["status"] == "sent"}) != 1:
            _fail("DeliveryChatMismatch")
    _verify_messages(config, directory, state)
    state.update(complete=True, verified=True)
    atomic_json(path, state)
    return {"complete": True, "verified": True,
            "parts": [{key: part[key] for key in ("name", "message_id", "chat_id", "create_time", "verified")} for part in state["parts"]]}
