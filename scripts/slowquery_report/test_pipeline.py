"""Synthetic integration tests, including the real installed cron entry."""
from contextlib import ExitStack
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from . import common, install, pipeline
from .common import ReportError
from .test_render import sample_packet


def config_for(root):
    return {"schema_version": 1, "state_dir": str(root / "state"),
            "aliyun_cli": str(root / "fake-aliyun"), "lark_cli": str(root / "fake-lark"),
            "node_cli": str(root / "fake-node"), "aliyun_profile": "synthetic", "aliyun_region": "us-test-1",
            "receiver": {"app_id": "cli_synthetic", "open_id": "ou_synthetic"},
            "clusters": [{"key": "primary_mysql", "instance_id": "pc-synthetic", "engine": "mysql"}],
            "code_wrap_checker": str(root / "checker.py"), "workers": 2}


class PipelineTests(unittest.TestCase):
    def test_raw_cli_errors_and_arguments_never_reach_output(self):
        fake = subprocess.CompletedProcess([], 1, "SYNTHETIC_PRIVATE_SENTINEL", "SYNTHETIC_PRIVATE_SENTINEL")
        with patch.object(common.subprocess, "run", return_value=fake), self.assertRaises(ReportError) as caught:
            common.cli_json(["fake"])
        self.assertEqual(str(caught.exception), "CliFailure")
        output = io.StringIO()
        with patch("sys.stdout", output), patch("sys.stderr", output):
            self.assertEqual(pipeline.main(["--SYNTHETIC_PRIVATE_SENTINEL"]), 1)
        self.assertNotIn("SYNTHETIC_PRIVATE_SENTINEL", output.getvalue())
        self.assertIn("InvalidArguments", output.getvalue())

    def test_config_is_strict_and_cli_env_does_not_inherit_secrets(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            config = config_for(root)
            path = root / "config.json"
            common.atomic_json(path, config)
            self.assertEqual(common.load_config(path), config)
            with patch.dict(os.environ, {"SYNTHETIC_PRIVATE_SENTINEL": "SYNTHETIC_PRIVATE_SENTINEL", "PATH": "/untrusted"}):
                env = common.cli_environment()
                self.assertEqual(set(env), {"HOME", "PATH", "LANG", "TZ"})
                self.assertNotIn("/untrusted", env["PATH"])
            config["unexpected"] = "SYNTHETIC_PRIVATE_SENTINEL"
            common.atomic_json(path, config)
            with self.assertRaises(ReportError):
                common.load_config(path)

    def test_lock_blocks_another_process(self):
        with tempfile.TemporaryDirectory() as temp, pipeline.run_lock(Path(temp)):
            with self.assertRaises(ReportError) as caught:
                with pipeline.run_lock(Path(temp)):
                    pass
            self.assertEqual(caught.exception.category, "ReportAlreadyRunning")

    def test_daily_halfday_and_no_send_routes_and_verification_gate(self):
        for mode, flags, sent in (("daily", [], True), ("daily", ["--no-send"], False),
                                   ("halfday", [], False), ("halfday", ["--send-self"], True)):
            with self.subTest(mode=mode, flags=flags), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                config = config_for(root)
                common.atomic_json(root / "config.json", config)
                packet = sample_packet(mode)
                args = pipeline.arguments(["--config", str(root / "config.json"), "--mode", mode, *flags])
                rendered = {"summary": "合成结论", "xml_name": "report.xml", "images": ["counts.png", "durations.png"]}
                with ExitStack() as stack:
                    stack.enter_context(patch("scripts.slowquery_report.collect.build_windows", return_value=packet))
                    collect = stack.enter_context(patch("scripts.slowquery_report.collect.collect_report", return_value=packet))
                    stack.enter_context(patch("scripts.slowquery_report.render.render_report", return_value=rendered))
                    stack.enter_context(patch("scripts.slowquery_report.delivery.verify_identity", return_value=config["receiver"]))
                    publish = stack.enter_context(patch("scripts.slowquery_report.delivery.publish_document", return_value={"verified": True, "url": "https://example.feishu.cn/docx/Synthetic"}))
                    delivery = stack.enter_context(patch("scripts.slowquery_report.delivery.deliver_self", return_value={"complete": True, "verified": True}))
                    stack.enter_context(patch("sys.stdout", io.StringIO()))
                    result = pipeline.run(args)
                    self.assertEqual(delivery.call_count, int(sent))
                    self.assertEqual(result["status"], "delivered" if sent else "published")
                    # Default windows are resolved once before collection.
                    self.assertEqual(collect.call_args.kwargs["day"] is None, mode == "halfday")
                    publish.return_value = {"verified": False}
                    delivery.reset_mock()
                    with self.assertRaises(ReportError):
                        pipeline.run(args)
                    delivery.assert_not_called()

    def test_frozen_package_resumes_without_collecting_or_rendering(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            config = config_for(root)
            packet = sample_packet()
            common.atomic_json(root / "config.json", config)
            directory = Path(config["state_dir"]) / "reports" / packet["report_key"]
            common.atomic_json(directory / "packet.json", packet)
            common.atomic_json(directory / "package-manifest.json", {})
            (directory / "summary.txt").write_text("已冻结\n")
            args = pipeline.arguments(["--config", str(root / "config.json"), "--dry-run"])
            with ExitStack() as stack:
                stack.enter_context(patch("scripts.slowquery_report.collect.build_windows", return_value={"report_key": packet["report_key"]}))
                collect = stack.enter_context(patch("scripts.slowquery_report.collect.collect_report", side_effect=AssertionError("must not collect")))
                render = stack.enter_context(patch("scripts.slowquery_report.render.render_report", side_effect=AssertionError("must not render")))
                delivery = stack.enter_context(patch("scripts.slowquery_report.delivery.publish_document"))
                with patch("sys.stdout", io.StringIO()):
                    result = pipeline.run(args)
            self.assertEqual(result["status"], "prepared")
            collect.assert_not_called()
            render.assert_not_called()
            delivery.assert_not_called()
            self.assertEqual((directory / "summary.txt").read_text(), "已冻结\n")

    def test_install_preserves_import_api_and_real_minimal_cron_entry(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            config = config_for(root)
            cfg = root / "config.json"
            common.atomic_json(cfg, config)
            fake = (f"#!{sys.executable}\nimport json,sys\n"
                    "a=sys.argv\n"
                    "if 'DescribeDBClusterAttribute' in a:\n"
                    " print(json.dumps({'DBNodes':[{'DBNodeId':'node_synthetic','DBNodeRole':'Writer'}]}))\n"
                    "else:\n"
                    " s=int(a[a.index('--StartTime')+1]); e=int(a[a.index('--EndTime')+1]); t=list(range(s,e+1,300000))\n"
                    " z=[0]*len(t)\n"
                    " print(json.dumps({'Code':'200','Success':'true','Data':{'IsFinish':True,'State':'SUCCESS','Data':{'Ts':t,'Count':z,'Rt':z,'TotalCount':0}}}))\n")
            Path(config["aliyun_cli"]).write_text(fake)
            Path(config["aliyun_cli"]).chmod(0o700)
            daily, domain = root / "daily.py", root / "domain.py"
            daily.write_text("raise RuntimeError('old daily must not run')\n")
            domain.write_text("def stat(x):\n    return x + 7\n\ndef main():\n    raise RuntimeError('old main must not run')\n\nif __name__ == '__main__':\n    main()\n")
            source = Path(__file__).resolve().parents[1]
            with patch("sys.stdout", io.StringIO()):
                install.install(source, config=cfg, state_dir=Path(config["state_dir"]), release_dir=root / "releases", daily_path=daily, domain_path=domain)
            imported = {"__name__": "synthetic_import"}
            exec(compile(domain.read_bytes(), "domain", "exec"), imported)
            self.assertEqual(imported["stat"](3), 10)
            env = {"HOME": str(Path.home()), "PATH": "/usr/bin:/bin", "LANG": "C.UTF-8", "TZ": "Asia/Shanghai"}
            result = subprocess.run([str(daily), "--day", "2020-01-02", "--dry-run"], env=env, capture_output=True, text=True, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('"ReportPrepared"', result.stdout)
            output = Path(config["state_dir"]) / "reports" / "daily-20200102"
            self.assertTrue((output / "counts.png").is_file())
            self.assertFalse((output / "document.json").exists())
            result = subprocess.run([sys.executable, str(domain), "--window-end", "2020-01-02T10:00:00+08:00", "--dry-run"], env=env, capture_output=True, text=True, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((Path(config["state_dir"]) / "reports/halfday-20200102-10/durations.png").is_file())

    def test_partial_install_disables_old_execution_instead_of_unsafe_rollback(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            daily, domain = root / "daily.py", root / "domain.py"
            daily.write_text("raise RuntimeError('old')\n")
            domain.write_text("def stat(): return 7\nif __name__ == '__main__':\n    raise RuntimeError('old')\n")
            original_write = install._write
            failed = False
            def injected(path, content, mode=0o700):
                nonlocal failed
                if path == domain and not failed:
                    failed = True
                    raise OSError("SYNTHETIC_PRIVATE_SENTINEL")
                return original_write(path, content, mode)
            with patch.object(install, "_write", side_effect=injected), self.assertRaises(ReportError) as caught:
                install.install(Path(__file__).resolve().parents[1], config=root / "config.json", state_dir=root / "state", release_dir=root / "release", daily_path=daily, domain_path=domain)
            self.assertEqual(caught.exception.category, "InstallFailure")
            for path in (daily, domain):
                result = subprocess.run([sys.executable, str(path)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 1)
                self.assertIn("ReportDisabled", result.stdout)
                self.assertNotIn("old", result.stderr)
            imported = {"__name__": "test"}
            exec(compile(domain.read_bytes(), "domain", "exec"), imported)
            self.assertEqual(imported["stat"](), 7)

    def test_unwritable_entry_does_not_prevent_disabling_other_entry(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            daily, domain = root / "daily.py", root / "domain.py"
            daily.write_text("raise RuntimeError('synthetic old daily')\n")
            domain.write_text("def stat(): return 7\nif __name__ == '__main__':\n    raise RuntimeError('synthetic old domain')\n")
            original_write = install._write
            def blocked(path, content, mode=0o700):
                if path == daily:
                    raise OSError("SYNTHETIC_PRIVATE_SENTINEL")
                return original_write(path, content, mode)
            with patch.object(install, "_write", side_effect=blocked), patch("sys.stdout", io.StringIO()), self.assertRaises(ReportError) as caught:
                install.install(Path(__file__).resolve().parents[1], config=root / "config.json", state_dir=root / "state", release_dir=root / "release", daily_path=daily, domain_path=domain)
            self.assertEqual(caught.exception.category, "InstallFailure")
            self.assertIn("ReportDisabled", domain.read_text())
            imported = {"__name__": "test"}
            exec(compile(domain.read_bytes(), "domain", "exec"), imported)
            self.assertEqual(imported["stat"](), 7)


if __name__ == "__main__":
    unittest.main()
