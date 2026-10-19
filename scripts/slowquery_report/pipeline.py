"""One locked, resumable path from safe numeric collection to self delivery."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import date, datetime
import fcntl
import os
from pathlib import Path
import time

from .common import TZ, ReportError, atomic_json, load_config, read_json, safe_event


class Arguments(argparse.ArgumentParser):
    def error(self, message):
        raise ReportError("InvalidArguments")


@contextmanager
def run_lock(state_dir):
    state_dir = Path(state_dir)
    state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state_dir / "run.lock").open("a") as stream:
        os.chmod(stream.name, 0o600)
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ReportError("ReportAlreadyRunning") from None
        try:
            yield
        finally:
            fcntl.flock(stream, fcntl.LOCK_UN)


def arguments(argv=None):
    parser = Arguments(description="Generate numeric slow-query charts and deliver to the pinned user.")
    parser.add_argument("--config", type=Path, default=Path.home() / ".config/daily-slowquery-report/config.json")
    parser.add_argument("--mode", choices=("daily", "halfday"), default="daily")
    parser.add_argument("--day")
    parser.add_argument("--window-end")
    parser.add_argument("--hours", type=int, choices=(24,), help="Compatibility option for the daily entry.")
    parser.add_argument("--refresh", action="store_true")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--dry-run", action="store_true", help="Collect/render locally without publishing or sending.")
    group.add_argument("--no-send", action="store_true", help="Publish the document without IM.")
    group.add_argument("--send-self", action="store_true", help="Also send the half-day report to self.")
    args = parser.parse_args(argv)
    try:
        args.day = date.fromisoformat(args.day) if args.day else None
        args.window_end = datetime.fromisoformat(args.window_end) if args.window_end else None
    except (ValueError, TypeError):
        raise ReportError("InvalidWindow") from None
    if args.mode == "halfday" and args.hours is not None:
        raise ReportError("InvalidArguments")
    return args


def run(args):
    from .collect import build_windows, collect_report
    from .delivery import deliver_self, publish_document, verify_identity
    from .render import render_report

    started = time.monotonic()
    config = load_config(args.config)
    windows = build_windows(day=args.day, mode=args.mode, window_end=args.window_end)
    state_dir = Path(config["state_dir"])
    with run_lock(state_dir):
        directory = state_dir / "reports" / windows["report_key"]
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        if not args.dry_run:
            safe_event("ReportStage", stage="IdentityCheck", report_key=windows["report_key"])
            verify_identity(config)
        if (directory / "package-manifest.json").exists():
            # Publishing freezes the original packet, prose and images forever.
            # Retry must never combine an old receipt with newly collected data.
            packet = read_json(directory / "packet.json")
            if not isinstance(packet, dict) or packet.get("report_key") != windows["report_key"]:
                raise ReportError("PackageInvalid")
            rendered = {"summary": (directory / "summary.txt").read_text(encoding="utf-8"),
                        "xml_name": "report.xml", "images": ["counts.png", "durations.png"]}
            safe_event("PackageResumed", report_key=windows["report_key"])
        else:
            safe_event("ReportStage", stage="Collect", report_key=windows["report_key"])
            # Resolve default dates once, even if collection crosses midnight.
            day = datetime.fromtimestamp(windows["start_ms"] / 1000, TZ).date() if args.mode == "daily" else None
            end = datetime.fromtimestamp(windows["end_ms"] / 1000, TZ) if args.mode == "halfday" else None
            packet = collect_report(config, day=day, mode=args.mode, window_end=end, refresh=args.refresh)
            if packet.get("report_key") != windows["report_key"]:
                raise ReportError("InvalidWindow")
            atomic_json(directory / "packet.json", packet)
            safe_event("ReportStage", stage="Render", report_key=windows["report_key"])
            rendered = render_report(packet, directory)
        failed = sum(period["status"] != "complete" for cluster in packet["clusters"] for period in cluster["periods"].values())
        safe_event("ReportPrepared", report_key=packet["report_key"], failed=failed, mode=args.mode)
        if args.dry_run:
            return {"status": "prepared", "report_key": packet["report_key"], "failed": failed}
        safe_event("ReportStage", stage="PublishDocument", report_key=windows["report_key"])
        document = publish_document(config, directory, rendered)
        if document.get("verified") is not True:
            raise ReportError("DocumentReadbackFailed")
        should_send = not args.no_send and (args.mode == "daily" or args.send_self)
        delivery = None
        if should_send:
            safe_event("ReportStage", stage="DeliverSelf", report_key=windows["report_key"])
            delivery = deliver_self(config, directory, rendered, document)
            if delivery.get("complete") is not True or delivery.get("verified") is not True:
                raise ReportError("DeliveryUnconfirmed")
        status = "delivered" if should_send else "published"
        if failed:
            status += "_with_gaps"
        result = {"schema_version": 1, "report_key": packet["report_key"], "status": status,
                  "data_complete": failed == 0, "failed_periods": failed,
                  "duration_scope_complete": all(c["duration_usable"] for c in packet["clusters"]),
                  "document": document, "delivery": delivery}
        atomic_json(state_dir / ("last-" + args.mode + ".json"), result)
        safe_event("ReportComplete", report_key=packet["report_key"], status=status, failed=failed,
                   verified=True, url=document["url"], elapsed_s=time.monotonic() - started)
        return result


def main(argv=None):
    os.umask(0o077)
    try:
        run(arguments(argv))
        return 0
    except ReportError as error:
        safe_event("ReportFailed", category=error.category)
        return 75 if error.category == "ReportAlreadyRunning" else 1
    except Exception:
        # Never put exception strings, argv, headers or an upstream body in logs.
        safe_event("ReportFailed", category="UnexpectedFailure")
        return 1
