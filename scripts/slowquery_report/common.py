"""Small, credential-independent helpers shared by the report stages."""
from __future__ import annotations

import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from datetime import timedelta, timezone

TZ = timezone(timedelta(hours=8))
LABELS = {"primary_mysql": "主 MySQL", "secondary_mysql": "次 MySQL", "postgres": "PostgreSQL"}
_CLI_PATHS: list[str] = []
_LOG_FIELDS = {"stage", "category", "mode", "report_key", "completed", "total", "count",
               "status", "part", "message_id", "doc_id", "url", "cluster", "period",
               "node_index", "elapsed_s", "cached", "verified", "success", "failed"}


class ReportError(Exception):
    """A fixed category, never an upstream body, command or exception string."""

    def __init__(self, category: str):
        self.category = category if isinstance(category, str) and re.fullmatch(r"[A-Z][A-Za-z0-9]{0,70}", category) else "UnexpectedFailure"
        super().__init__(self.category)


def atomic_json(path, obj):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        content = json.dumps(obj, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False)
        fd, temporary = tempfile.mkstemp(prefix="." + path.name + "-", dir=path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    except (OSError, TypeError, ValueError):
        raise ReportError("StateWriteFailure") from None


def read_json(path):
    try:
        path = Path(path)
        if path.stat().st_size > 20 * 1024 * 1024:
            raise ReportError("StateTooLarge")
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError):
        raise ReportError("StateReadFailure") from None


def safe_event(event, **fields):
    name = event if isinstance(event, str) and re.fullmatch(r"[A-Z][A-Za-z0-9]{0,70}", event) else "ReportEvent"
    out = {"event": name}
    for key, value in fields.items():
        if key not in _LOG_FIELDS:
            continue
        if value is None or isinstance(value, (bool, int)):
            out[key] = value
        elif isinstance(value, float) and math.isfinite(value):
            out[key] = round(value, 3)
        elif isinstance(value, str):
            # Call sites pass only fixed categories, window labels and verified IDs.
            # Arbitrary upstream text and credential-shaped values never pass here.
            if re.search(r"(?i)(?:sk-|bearer|secret|authorization|password|api.?key)", value):
                continue
            if re.fullmatch(r"[A-Za-z0-9_:./+\-]{1,180}", value):
                out[key] = value
    print(json.dumps(out, ensure_ascii=False, allow_nan=False), flush=True)


def configure_cli_paths(config):
    global _CLI_PATHS
    candidates = [str(Path(config[key]).parent) for key in ("aliyun_cli", "lark_cli", "node_cli")]
    candidates += [str(Path(sys.executable).parent), "/usr/local/bin", "/usr/bin", "/bin"]
    _CLI_PATHS = list(dict.fromkeys(candidates))


def cli_environment():
    paths = _CLI_PATHS or [str(Path(sys.executable).parent), "/usr/local/bin", "/usr/bin", "/bin"]
    return {"HOME": str(Path.home()), "PATH": os.pathsep.join(paths), "LANG": "C.UTF-8", "TZ": "Asia/Shanghai"}


def cli_json(argv, *, cwd=None, timeout=120, error_category="CliFailure"):
    try:
        response = subprocess.run([str(x) for x in argv], cwd=cwd, env=cli_environment(),
                                  capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        raise ReportError("CliTimeout") from None
    except (OSError, ValueError):
        raise ReportError(error_category) from None
    if response.returncode:
        raise ReportError(error_category)
    try:
        result = json.loads(response.stdout)
    except (ValueError, TypeError):
        raise ReportError("CliInvalidJSON") from None
    if not isinstance(result, dict):
        raise ReportError("CliInvalidJSON")
    return result


def load_config(path):
    config = read_json(path)
    required = {"schema_version", "state_dir", "aliyun_cli", "lark_cli", "node_cli", "aliyun_profile", "aliyun_region",
                "receiver", "clusters", "code_wrap_checker", "workers"}
    if not isinstance(config, dict) or set(config) != required or type(config.get("schema_version")) is not int or config["schema_version"] != 1:
        raise ReportError("InvalidConfig")
    for field in ("state_dir", "aliyun_cli", "lark_cli", "node_cli", "code_wrap_checker"):
        value = config[field]
        if not isinstance(value, str) or not Path(value).is_absolute() or "\x00" in value:
            raise ReportError("InvalidConfig")
    if not isinstance(config["aliyun_profile"], str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", config["aliyun_profile"]):
        raise ReportError("InvalidConfig")
    if not isinstance(config["aliyun_region"], str) or not re.fullmatch(r"[a-z0-9-]{1,50}", config["aliyun_region"]):
        raise ReportError("InvalidConfig")
    receiver = config["receiver"]
    if not isinstance(receiver, dict) or set(receiver) != {"app_id", "open_id"}:
        raise ReportError("InvalidConfig")
    for key, prefix in (("app_id", "cli_"), ("open_id", "ou_")):
        if not isinstance(receiver[key], str) or not re.fullmatch(prefix + r"[A-Za-z0-9]{1,80}", receiver[key]):
            raise ReportError("InvalidConfig")
    clusters = config["clusters"]
    if not isinstance(clusters, list) or not 1 <= len(clusters) <= 3:
        raise ReportError("InvalidConfig")
    seen = set()
    for cluster in clusters:
        if not isinstance(cluster, dict) or set(cluster) != {"key", "instance_id", "engine"}:
            raise ReportError("InvalidConfig")
        if cluster["key"] not in LABELS or cluster["key"] in seen:
            raise ReportError("InvalidConfig")
        seen.add(cluster["key"])
        expected_engine = "postgres" if cluster["key"] == "postgres" else "mysql"
        if cluster["engine"] != expected_engine or not isinstance(cluster["instance_id"], str) or not re.fullmatch(r"pc-[a-z0-9]{2,60}", cluster["instance_id"]):
            raise ReportError("InvalidConfig")
    if type(config["workers"]) is not int or not 1 <= config["workers"] <= 4:
        raise ReportError("InvalidConfig")
    configure_cli_paths(config)
    return config
