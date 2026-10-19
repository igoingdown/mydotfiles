"""Synthetic delivery recovery tests; no network, real IDs or report data."""

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from . import delivery
from .common import ReportError, atomic_json, read_json


SYNTHETIC_EXTRA = "synthetic-only-do-not-forward"
DOCUMENT = {"document_id": "SyntheticDoc", "url": "https://example.feishu.cn/docx/SyntheticDoc"}
XML = ('<title>合成慢查询日报</title><p>次数、耗时及数据完整性。</p>'
       '<table><colgroup><col width="410"/><col width="410"/></colgroup>'
       '<thead><tr><th>指标</th><th>值</th></tr></thead>'
       '<tbody><tr><td>合成次数</td><td>12</td></tr></tbody></table>')


class FakeCLI:
    def __init__(self, config):
        self.config = config
        self.calls = []
        self.document_xml = XML
        self.send_responses = {}
        self.fail_part = None
        self.fail_create = False
        self.fail_insert_after = False
        self.fail_insert_before = False
        self.bad_readback = False
        self.wrong_chat = False
        self.extra_image = False
        self.wrap_failure = False
        self.wrap_fixed = False

    def __call__(self, argv, **kwargs):
        self.calls.append((list(argv), kwargs))
        if argv[0] == sys.executable:
            if "--fix" in argv:
                self.wrap_fixed = True
                return {"verified": True}
            if self.wrap_failure and not self.wrap_fixed:
                raise ReportError("DocumentWrapCheckFailed")
            return {"verified": True, "code_blocks": 0}
        if argv[1:3] == ["auth", "status"]:
            return {"appId": self.config["receiver"]["app_id"], "verified": True,
                    "identities": {"user": {"openId": self.config["receiver"]["open_id"], "status": "ready", "tokenStatus": "valid"},
                                   "bot": {"openId": "ou_syntheticBot"}}, "extra": SYNTHETIC_EXTRA}
        if argv[1:3] == ["docs", "+create"]:
            if self.fail_create:
                raise ReportError("CliTimeout")
            return {"ok": True, "data": {"document": {**DOCUMENT, "extra": SYNTHETIC_EXTRA}}}
        if argv[1:3] == ["docs", "+fetch"]:
            value = self.document_xml
            if self.extra_image:
                value += '<img token="img_extra"/>'
            return {"ok": True, "data": {"document": {"document_id": DOCUMENT["document_id"], "content": value}}}
        if argv[1:3] == ["docs", "+media-insert"]:
            if self.fail_insert_before:
                self.fail_insert_before = False
                raise ReportError("CliTimeout")
            name = argv[argv.index("--file") + 1]
            self.document_xml += '<img token="img_' + Path(name).stem + '"/>'
            if self.fail_insert_after:
                self.fail_insert_after = False
                raise ReportError("CliTimeout")
            return {"ok": True, "data": {"document_id": DOCUMENT["document_id"], "block_id": "syntheticBlock"}}
        if argv[1:3] == ["im", "+messages-send"]:
            name = "summary" if "--markdown" in argv else Path(argv[argv.index("--image") + 1]).stem
            if self.fail_part == name:
                self.fail_part = None
                raise ReportError("CliTimeout")
            receipt = {"message_id": "om_" + name, "chat_id": "oc_syntheticSelf", "create_time": "2030-01-03 09:50:12"}
            self.send_responses[receipt["message_id"]] = {**receipt, "msg_type": "post" if name == "summary" else "image"}
            return {"ok": True, "code": 0, "data": {**receipt, "extra": SYNTHETIC_EXTRA}}
        if argv[1:3] == ["im", "+messages-mget"]:
            messages = copy.deepcopy(list(self.send_responses.values()))
            if self.bad_readback:
                messages = messages[:-1]
            for message in messages:
                message["create_time"] = "2030-01-03 09:50"
                message["content"] = SYNTHETIC_EXTRA
                if self.wrong_chat:
                    message["chat_id"] = "oc_syntheticOther"
            return {"ok": True, "data": {"messages": messages, "total": len(messages)}}
        raise AssertionError("Unexpected synthetic command")

    def count(self, action):
        return sum(argv[1:3] == action for argv, _ in self.calls)


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.config = {"lark_cli": "synthetic-lark-cli", "code_wrap_checker": "synthetic-checker.py",
                       "receiver": {"app_id": "cli_syntheticApp", "open_id": "ou_syntheticUser"}}
        self.rendered = {"summary": "合成结论：次数 12，数据完整。", "xml_name": "report.xml", "images": list(delivery.IMAGES)}
        atomic_json(self.directory / "packet.json", {"schema_version": 1, "report_key": "daily-20300102"})
        (self.directory / "report.xml").write_text(XML, encoding="utf-8")
        for name in delivery.IMAGES:
            (self.directory / name).write_bytes(b"synthetic-image-bytes")
        self.cli = FakeCLI(self.config)
        self.patch_cli = patch.object(delivery, "cli_json", self.cli)
        self.patch_cli.start()
        self.addCleanup(self.patch_cli.stop)

    def publish(self):
        return delivery.publish_document(self.config, self.directory, self.rendered)

    def send(self, document):
        return delivery.deliver_self(self.config, self.directory, self.rendered, document)

    def test_complete_publish_and_send_uses_explicit_identities_and_safe_state(self):
        document = self.publish()
        result = self.send(document)
        self.assertTrue(result["complete"])
        self.assertTrue(result["verified"])
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 3)
        self.assertEqual(self.cli.count(["docs", "+media-insert"]), 2)
        for argv, kwargs in self.cli.calls:
            if argv[1:2] == ["im"]:
                self.assertEqual(argv[argv.index("--as") + 1], "bot")
            elif argv[1:2] == ["docs"]:
                self.assertEqual(argv[argv.index("--as") + 1], "user")
                self.assertEqual(kwargs["cwd"], self.directory)
        for name in ("package-manifest.json", "document.json", "outbox.json"):
            self.assertNotIn(SYNTHETIC_EXTRA, (self.directory / name).read_text())

    def test_user_pin_never_accepts_bot_identity(self):
        def bot_only(argv, **kwargs):
            return {"appId": self.config["receiver"]["app_id"], "verified": True,
                    "identities": {"bot": {"openId": self.config["receiver"]["open_id"]}}}
        with patch.object(delivery, "cli_json", bot_only), self.assertRaisesRegex(ReportError, "IdentityMismatch"):
            delivery.verify_identity(self.config)

    def test_identity_mismatch_stops_before_any_document_write(self):
        def wrong_identity(argv, **kwargs):
            return {"appId": "cli_syntheticOther", "verified": True,
                    "identities": {"user": {"openId": self.config["receiver"]["open_id"]}}}
        with patch.object(delivery, "cli_json", wrong_identity), self.assertRaisesRegex(ReportError, "IdentityMismatch"):
            self.publish()
        self.assertFalse((self.directory / "document.json").exists())

    def test_expired_user_auth_is_not_accepted_by_a_true_verified_field(self):
        def expired_identity(argv, **kwargs):
            return {"appId": self.config["receiver"]["app_id"], "verified": True,
                    "identities": {"user": {"openId": self.config["receiver"]["open_id"], "status": "ready", "tokenStatus": "expired"}}}
        with patch.object(delivery, "cli_json", expired_identity), self.assertRaisesRegex(ReportError, "IdentityCheckFailed"):
            self.publish()
        self.assertFalse((self.directory / "document.json").exists())

    def test_package_changed_blocks_publish_and_send(self):
        document = self.publish()
        (self.directory / "counts.png").write_bytes(b"different-synthetic-image")
        with self.assertRaisesRegex(ReportError, "PackageChanged"):
            self.send(document)
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 0)

    def test_manifest_frozen_summary_cannot_be_replaced(self):
        self.publish()
        changed = {**self.rendered, "summary": "变更后的合成结论。"}
        with self.assertRaisesRegex(ReportError, "PackageChanged"):
            delivery.publish_document(self.config, self.directory, changed)
        self.assertEqual((self.directory / "summary.txt").read_text(), self.rendered["summary"])

    def test_unknown_document_create_is_not_blindly_retried(self):
        self.cli.fail_create = True
        with self.assertRaisesRegex(ReportError, "CliTimeout"):
            self.publish()
        self.cli.fail_create = False
        with self.assertRaisesRegex(ReportError, "DocumentPendingReview"):
            self.publish()
        self.assertEqual(self.cli.count(["docs", "+create"]), 1)

    def test_unknown_insert_recovers_from_known_document_image_count(self):
        self.cli.fail_insert_after = True
        with self.assertRaisesRegex(ReportError, "CliTimeout"):
            self.publish()
        document = self.publish()
        self.assertTrue(document["verified"])
        self.assertEqual(self.cli.count(["docs", "+create"]), 1)
        self.assertEqual(self.cli.count(["docs", "+media-insert"]), 2)

    def test_unknown_insert_with_no_completed_image_stays_pending(self):
        self.cli.fail_insert_before = True
        with self.assertRaisesRegex(ReportError, "CliTimeout"):
            self.publish()
        with self.assertRaisesRegex(ReportError, "DocumentPendingReview"):
            self.publish()
        self.assertEqual(self.cli.count(["docs", "+media-insert"]), 1)

    def test_wrap_failure_runs_fix_and_a_separate_recheck(self):
        self.cli.wrap_failure = True
        self.assertTrue(self.publish()["verified"])
        commands = [argv for argv, _ in self.cli.calls if argv[0] == sys.executable]
        self.assertEqual(len(commands), 3)
        self.assertNotIn("--fix", commands[0])
        self.assertIn("--fix", commands[1])
        self.assertNotIn("--fix", commands[2])

    def test_wrong_table_width_prevents_im(self):
        self.cli.document_xml = XML.replace('width="410"', 'width="409"', 1)
        with self.assertRaisesRegex(ReportError, "DocumentTableWidthFailed"):
            self.publish()
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 0)

    def test_failed_fresh_verification_revokes_previous_document_approval(self):
        document = self.publish()
        self.cli.document_xml = self.cli.document_xml.replace('width="410"', 'width="409"', 1)
        with self.assertRaisesRegex(ReportError, "DocumentTableWidthFailed"):
            self.publish()
        with self.assertRaisesRegex(ReportError, "DocumentNotVerified"):
            self.send(document)
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 0)

    def test_extra_image_cannot_be_reported_as_verified(self):
        self.cli.extra_image = True
        with self.assertRaisesRegex(ReportError, "DocumentReadbackFailed"):
            self.publish()
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 0)

    def test_added_text_or_changed_numeric_value_fails_full_readback(self):
        for value in (XML + "<p>意外多出的数字 999。</p>", XML.replace("<td>12</td>", "<td>13</td>")):
            with self.subTest(value=value):
                expected = delivery._xml(XML)
                actual = delivery._xml(value)
                with self.assertRaisesRegex(ReportError, "Document(?:Table)?ContentMismatch"):
                    delivery._check_document_content(actual, expected, 0)

    def test_cell_boundary_digit_redistribution_is_rejected(self):
        expected_xml = XML.replace("<td>合成次数</td><td>12</td>", "<td>1</td><td>23</td>")
        changed_xml = expected_xml.replace("<td>1</td><td>23</td>", "<td>12</td><td>3</td>")
        expected, actual = delivery._xml(expected_xml), delivery._xml(changed_xml)
        self.assertEqual(delivery._compact_text(expected), delivery._compact_text(actual))
        with self.assertRaisesRegex(ReportError, "DocumentTableContentMismatch"):
            delivery._check_document_content(actual, expected, 0)

    def test_table_container_and_header_tag_normalization_is_allowed(self):
        converted = XML.replace("<thead>", "").replace("</thead>", "").replace("<tbody>", "").replace("</tbody>", "")
        converted = converted.replace("<th>", "<td>").replace("</th>", "</td>")
        delivery._check_document_content(delivery._xml(converted), delivery._xml(XML), 0)

    def test_partial_send_resumes_only_unsent_parts_with_original_key_and_time(self):
        document = self.publish()
        self.cli.fail_part = "counts"
        with patch.object(delivery.time, "time", return_value=1000), self.assertRaisesRegex(ReportError, "CliTimeout"):
            self.send(document)
        first = read_json(self.directory / "outbox.json")
        self.assertEqual([p["status"] for p in first["parts"]], ["sent", "sending", "ready"])
        with patch.object(delivery.time, "time", return_value=1100):
            self.assertTrue(self.send(document)["complete"])
        second = read_json(self.directory / "outbox.json")
        self.assertEqual(first["parts"][1]["first_attempt_at"], second["parts"][1]["first_attempt_at"])
        self.assertEqual(first["parts"][1]["idempotency_key"], second["parts"][1]["idempotency_key"])
        summary_sends = [argv for argv, _ in self.cli.calls if argv[1:3] == ["im", "+messages-send"] and "--markdown" in argv]
        self.assertEqual(len(summary_sends), 1)

    def test_unknown_send_at_55_minutes_is_not_retried(self):
        document = self.publish()
        self.cli.fail_part = "summary"
        with patch.object(delivery.time, "time", return_value=1000), self.assertRaises(ReportError):
            self.send(document)
        with patch.object(delivery.time, "time", return_value=1000 + delivery.RETRY_SECONDS), self.assertRaisesRegex(ReportError, "DeliveryPendingReview"):
            self.send(document)
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 1)
        self.assertEqual(read_json(self.directory / "outbox.json")["parts"][0]["first_attempt_at"], 1000)

    def test_clock_rollback_never_extends_unknown_send_window(self):
        document = self.publish()
        self.cli.fail_part = "summary"
        with patch.object(delivery.time, "time", return_value=1000), self.assertRaises(ReportError):
            self.send(document)
        with patch.object(delivery.time, "time", return_value=999), self.assertRaisesRegex(ReportError, "DeliveryPendingReview"):
            self.send(document)
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 1)

    def test_all_sent_but_failed_readback_is_never_sent_again(self):
        document = self.publish()
        self.cli.bad_readback = True
        with self.assertRaisesRegex(ReportError, "DeliveryReadbackFailed"):
            self.send(document)
        self.assertTrue(all(p["status"] == "sent" for p in read_json(self.directory / "outbox.json")["parts"]))
        self.cli.bad_readback = False
        with patch.object(delivery.time, "time", return_value=10 ** 9):
            self.assertTrue(self.send(document)["complete"])
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 3)

    def test_readback_to_other_chat_cannot_mark_complete(self):
        document = self.publish()
        self.cli.wrong_chat = True
        with self.assertRaisesRegex(ReportError, "DeliveryReadbackFailed"):
            self.send(document)
        self.assertFalse(read_json(self.directory / "outbox.json")["complete"])

    def test_saved_recipient_drift_is_rejected_without_send(self):
        document = self.publish()
        self.send(document)
        outbox = read_json(self.directory / "outbox.json")
        outbox["receiver"]["open_id"] = "ou_syntheticOther"
        atomic_json(self.directory / "outbox.json", outbox)
        with self.assertRaisesRegex(ReportError, "IdentityMismatch"):
            self.send(document)
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 3)

    def test_document_not_verified_is_rejected_without_send(self):
        document = self.publish()
        state = read_json(self.directory / "document.json")
        state["verified"] = False
        atomic_json(self.directory / "document.json", state)
        with self.assertRaisesRegex(ReportError, "DocumentNotVerified"):
            self.send(document)
        self.assertEqual(self.cli.count(["im", "+messages-send"]), 0)

    def test_untrusted_document_urls_are_rejected(self):
        for url in ("https://example.invalid/docx/SyntheticDoc",
                    "https://example.feishu.cn/docx/SyntheticDoc?synthetic=1",
                    "https://user@example.feishu.cn/docx/SyntheticDoc",
                    "http://example.feishu.cn/docx/SyntheticDoc",
                    "https://example.feishu.cn:443/docx/SyntheticDoc"):
            with self.subTest(url=url), self.assertRaisesRegex(ReportError, "DocumentResponseInvalid"):
                delivery._valid_document({"document_id": "SyntheticDoc", "url": url})

    def test_nonzero_api_code_with_receipt_is_not_success(self):
        with self.assertRaisesRegex(ReportError, "DeliverySendUnconfirmed"):
            delivery._receipt({"ok": True, "code": 1, "data": {"message_id": "om_synthetic", "chat_id": "oc_synthetic", "create_time": "1000"}})

    def test_cli_receipt_time_formats_remain_unmodified_metadata(self):
        for created in ("2030-01-03 09:50:12", "2030-01-03 09:50", "1893625812000", 1893625812):
            with self.subTest(created=created):
                response = {"ok": True, "data": {"message_id": "om_synthetic", "chat_id": "oc_synthetic", "create_time": created}}
                self.assertEqual(delivery._receipt(response)["create_time"], str(created))

    def test_malformed_or_impossible_receipt_times_are_rejected(self):
        for created in ("2030-02-30 09:50", "2030-01-03 24:00:00", "2030-1-3 09:50", "2030-01-03 09:50 trailing",
                        "2030-01-03 09:50\n", "", "0", -1, True, 1.5, {"extra": SYNTHETIC_EXTRA}):
            with self.subTest(created=created), self.assertRaisesRegex(ReportError, "DeliverySendUnconfirmed"):
                delivery._receipt_time(created)


if __name__ == "__main__":
    unittest.main()
