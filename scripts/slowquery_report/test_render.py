"""Synthetic-only checks of reader-facing semantics and data rejection."""
from copy import deepcopy
import csv
from datetime import datetime
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

from .common import LABELS, TZ, ReportError
from . import render


def sample_packet(mode="daily"):
    """A fictitious future window, with no hosts, identities or query text."""
    hours = 24 if mode == "daily" else 12
    end = datetime(2030, 1, 17, 0 if hours == 24 else 10, tzinfo=TZ)
    end_ms = int(end.timestamp() * 1000)
    start = end_ms - hours * render.HOUR
    refs = {"current": str(start), "previous": str(start - hours * render.HOUR),
            "previous_day": str(start - render.DAY), "previous_week": str(start - 7 * render.DAY),
            "recent": [str(start - i * render.DAY) for i in range(6, -1, -1)]}
    keys = sorted(set(refs["recent"]) | {refs[k] for k in ("current", "previous", "previous_day", "previous_week")}, key=int)
    periods = [{"key": k, "start_ms": int(k), "end_ms": int(k) + hours * render.HOUR,
                "label": datetime.fromtimestamp(int(k) / 1000, TZ).strftime("%m-%d")} for k in keys]
    clusters = []
    for index, key in enumerate(LABELS):
        pg = key == "postgres"
        results = {}
        for k in keys:
            hourly = [{"ts": int(k) + i * render.HOUR, "count": (i % 4 + index + 1) * (int(k) // render.DAY % 3 + 1),
                       "duration_seconds": None if pg else (i % 4 + index + 1) * .25}
                      for i in range(hours)]
            results[k] = {"status": "complete", "category": None, "count": sum(p["count"] for p in hourly),
                          "duration_seconds": None if pg else sum(p["duration_seconds"] for p in hourly),
                          "hourly": hourly, "reconciled": True}
        clusters.append({"key": key, "label": LABELS[key], "engine": "postgres" if pg else "mysql",
                         "scope": "all_logs_business_scope_unverified" if pg else "current_nodes_all_accounts",
                         "duration_usable": not pg, "node_count": 1, "inventory_changed": False, "periods": results})
    return {"schema_version": 1, "report_key": "daily-20300116" if hours == 24 else "halfday-20300117-10",
            "mode": mode, "start_ms": start, "end_ms": end_ms, "window_hours": hours,
            "generated_at": end.isoformat(), "refs": refs, "periods": periods, "clusters": clusters}


def failed_period():
    return {"status": "failed", "category": "ReconciliationFailure", "count": None,
            "duration_seconds": None, "hourly": [], "reconciled": False}


class RenderTests(unittest.TestCase):
    def test_both_modes_render_real_png_xml_csv_and_three_conclusions(self):
        from PIL import Image
        for mode in ("daily", "halfday"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temp:
                packet = sample_packet(mode)
                result = render.render_report(packet, Path(temp))
                self.assertEqual(result["images"], ["counts.png", "durations.png"])
                self.assertEqual(len(result["summary"].splitlines()), 3)
                self.assertEqual((Path(temp) / "summary.txt").read_text(), result["summary"] + "\n")
                for name in result["images"]:
                    with Image.open(Path(temp) / name) as image:
                        self.assertEqual(image.format, "PNG")
                        self.assertGreater(image.width, 1000)
                        self.assertGreater(image.height, 1000)
                        image.verify()
                xml = (Path(temp) / "report.xml").read_text()
                tree = ET.fromstring("<root>" + xml + "</root>")
                self.assertEqual(sum(int(c.attrib["width"]) for c in tree.findall(".//colgroup/col")), 820)
                self.assertFalse(tree.findall(".//img"))
                self.assertFalse(tree.findall(".//code") + tree.findall(".//pre"))
                self.assertEqual(len(tree.findall(".//tbody/tr")), 6)
                self.assertIn("业务与后台未分离", xml)
                self.assertIn("业务耗时待核", xml)
                self.assertIn("不判断查询效率", xml)
                for name in ("hour.csv", "daily.csv"):
                    self.assertTrue((Path(temp) / name).exists())
                with (Path(temp) / "hour.csv").open(encoding="utf-8-sig", newline="") as stream:
                    rows = list(csv.DictReader(stream))
                pg = [row for row in rows if row["集群"] == LABELS["postgres"]]
                self.assertTrue(pg)
                self.assertTrue(all(row["累计耗时（秒）"] == "待核" for row in pg))
                if mode == "halfday":
                    self.assertIn("慢查询十二小时巡检", xml)
                    self.assertIn("前一日同窗", xml)
                    self.assertIn("不代表七个完整自然日", xml)

    def test_line_styles_values_and_pg_duration_panel(self):
        packet = sample_packet()
        counts = render._figure(packet, "count")
        durations = render._figure(packet, "duration_seconds")
        try:
            count_axes = [axis for axis in counts.axes if "分小时对照" in axis.get_title(loc="left")]
            duration_axes = [axis for axis in durations.axes if "分小时对照" in axis.get_title(loc="left")]
            self.assertEqual(len(count_axes), 3)
            self.assertEqual([line.get_linestyle() for line in count_axes[0].lines], ["-", "--", "-."])
            expected = packet["clusters"][0]["periods"][packet["refs"]["current"]]["hourly"]
            self.assertEqual(list(count_axes[0].lines[0].get_ydata()), [p["count"] for p in expected])
            self.assertEqual(list(duration_axes[0].lines[0].get_ydata()), [p["duration_seconds"] for p in expected])
            self.assertEqual(len(count_axes[2].lines), 3)
            self.assertEqual(len(duration_axes[2].lines), 0)
            self.assertEqual(len(duration_axes[2].get_yticks()), 0)
            self.assertTrue(any("业务耗时待核" in t.get_text() for t in duration_axes[2].texts))
            pg_trend = [axis for axis in durations.axes if "PostgreSQL" in axis.get_title(loc="left") and "趋势" in axis.get_title(loc="left")][0]
            self.assertEqual(len(pg_trend.patches), 0)
            self.assertEqual(len(pg_trend.get_yticks()), 0)
        finally:
            counts.clear()
            durations.clear()

    def test_missing_windows_are_gaps_in_lines_and_bars_and_not_changes(self):
        packet = sample_packet()
        cluster = packet["clusters"][0]
        cluster["periods"][packet["refs"]["current"]] = failed_period()
        render._validate_packet(packet)
        summary = render._summary(packet)
        self.assertIn("主 MySQL：当前窗口数据缺失", summary)
        self.assertIn("数据不完整", render._title(packet))
        figure = render._figure(packet, "count")
        try:
            hourly = [a for a in figure.axes if a.get_title(loc="left").startswith("主 MySQL") and "分小时" in a.get_title(loc="left")][0]
            self.assertEqual([line.get_label() for line in hourly.lines], ["前天", "上周同日"])
            trend = [a for a in figure.axes if a.get_title(loc="left").startswith("主 MySQL") and "趋势" in a.get_title(loc="left")][0]
            self.assertEqual(len(trend.patches), 6)
        finally:
            figure.clear()

    def test_zero_baselines_do_not_produce_infinite_percentages(self):
        self.assertEqual(render._change(0, 0), "持平")
        self.assertEqual(render._change(5, 0), "由零增加")
        self.assertEqual(render._change(0, 5), "减少100.0%")
        self.assertEqual(render._change(5, None), "无可比数据")
        self.assertEqual(render._change(None, 5), "无可比数据")
        self.assertEqual(render._change(100.001, 100), "增加不足0.1%")
        self.assertEqual(render._fmt(.02, "duration_seconds"), "0.02")
        self.assertEqual(render._fmt(.00001, "duration_seconds"), "不足0.001")

    def test_true_zero_is_a_real_line_with_readable_count_scale(self):
        packet = sample_packet()
        for cluster in packet["clusters"]:
            for result in cluster["periods"].values():
                result["count"] = 0
                for point in result["hourly"]:
                    point["count"] = 0
        render._validate_packet(packet)
        figure = render._figure(packet, "count")
        try:
            for axis in figure.axes:
                self.assertGreaterEqual(axis.get_ylim()[1], 1)
                if "分小时" in axis.get_title(loc="left"):
                    self.assertEqual(len(axis.lines), 3)
                    self.assertTrue(all(all(value == 0 for value in line.get_ydata()) for line in axis.lines))
                else:
                    self.assertEqual(len(axis.patches), 7)
                    self.assertEqual(len([text for text in axis.texts if text.get_text() == "0"]), 7)
        finally:
            figure.clear()

    def test_reconciliation_mismatch_and_incomplete_verification_have_distinct_chinese_reasons(self):
        packet = sample_packet()
        cases = (("HourlyReconciliationFailure", "小时口径对账不一致"),
                 ("HourlyVerificationIncomplete", "独立小时核验未完成"),
                 ("InvalidHistogramState", "统计状态未确认完成"))
        for category, expected in cases:
            result = failed_period()
            result["category"] = category
            packet["clusters"][0]["periods"][packet["refs"]["current"]] = result
            xml = render._xml(packet, render._summary(packet))
            self.assertIn(expected, xml)
            self.assertNotIn(category, xml)

    def test_pg_totals_never_influence_mysql_summary_or_peak(self):
        packet = sample_packet()
        before = render._summary(packet)
        for result in packet["clusters"][2]["periods"].values():
            for point in result["hourly"]:
                point["count"] = 10**8
            result["count"] = sum(p["count"] for p in result["hourly"])
        render._validate_packet(packet)
        self.assertEqual(render._summary(packet), before)

    def test_inventory_changes_and_missing_cluster_are_explicit(self):
        packet = sample_packet()
        packet["clusters"][0]["inventory_changed"] = True
        packet["clusters"].pop(1)
        render._validate_packet(packet)
        self.assertIn("次 MySQL：未配置", render._summary(packet))
        self.assertIn("节点清单有变化", render._summary(packet))
        self.assertIn("不覆盖已退役节点", "".join(render._scope(packet)))
        self.assertIn("仅覆盖本轮当前节点", "".join(render._scope(packet)))

    def test_failed_category_never_appears_in_document_or_csv(self):
        packet = sample_packet()
        result = failed_period()
        result["category"] = "SyntheticPrivateSentinel"
        packet["clusters"][0]["periods"][packet["refs"]["current"]] = result
        render._validate_packet(packet)
        with tempfile.TemporaryDirectory() as temp:
            render._write_csv(packet, Path(temp))
            texts = [render._summary(packet), render._xml(packet, render._summary(packet))]
            texts += [f.read_text(encoding="utf-8-sig") for f in Path(temp).glob("*.csv")]
        self.assertTrue(all("SyntheticPrivateSentinel" not in text for text in texts))

    def test_invalid_inputs_fail_before_writing_or_logging(self):
        def extra(packet): packet["SQLText"] = "SYNTHETIC_PRIVATE_SENTINEL"
        def label(packet): packet["clusters"][0]["label"] = "SYNTHETIC_PRIVATE_SENTINEL"
        def period_label(packet): packet["periods"][0]["label"] = "SYNTHETIC_PRIVATE_SENTINEL"
        def point_extra(packet): packet["clusters"][0]["periods"][packet["refs"]["current"]]["hourly"][0]["raw_error"] = "SYNTHETIC_PRIVATE_SENTINEL"
        def bad_time(packet): packet["start_ms"] += 1
        def bad_refs(packet): packet["refs"]["previous_day"] = packet["refs"]["current"]
        def bad_mode(packet): packet["mode"] = "SYNTHETIC_PRIVATE_SENTINEL"
        def duplicate(packet): packet["clusters"].append(deepcopy(packet["clusters"][0]))
        cases = (extra, label, period_label, point_extra, bad_time, bad_refs, bad_mode, duplicate)
        for mutate in cases:
            packet = sample_packet()
            mutate(packet)
            with self.subTest(mutate=mutate.__name__), tempfile.TemporaryDirectory() as temp:
                path = Path(temp) / "not-created"
                stdout, stderr = io.StringIO(), io.StringIO()
                with patch("sys.stdout", stdout), patch("sys.stderr", stderr):
                    with self.assertRaises(ReportError) as caught:
                        render.render_report(packet, path)
                self.assertEqual(str(caught.exception), "InvalidPacket")
                self.assertFalse(path.exists())
                self.assertEqual(stdout.getvalue() + stderr.getvalue(), "")

    def test_complete_requires_reconciliation_conservation_and_pg_null_duration(self):
        for key in LABELS:
            for failure in ("unreconciled", "count_mismatch", "missing_hour", "wrong_timestamp", "boolean_count", "nan", "duration"):
                packet = sample_packet()
                cluster = next(c for c in packet["clusters"] if c["key"] == key)
                result = cluster["periods"][packet["refs"]["current"]]
                if failure == "unreconciled": result["reconciled"] = False
                elif failure == "count_mismatch": result["count"] += 1
                elif failure == "missing_hour": result["hourly"].pop()
                elif failure == "wrong_timestamp": result["hourly"][0]["ts"] += render.HOUR
                elif failure == "boolean_count": result["hourly"][0]["count"] = True
                elif failure == "nan": result["duration_seconds"] = float("nan")
                else: result["duration_seconds"] = 1 if key == "postgres" else result["duration_seconds"] + 1
                with self.subTest(key=key, failure=failure):
                    with self.assertRaises(ReportError): render._validate_packet(packet)

    def test_pg_hour_duration_is_rejected_even_when_total_is_null(self):
        packet = sample_packet()
        packet["clusters"][2]["periods"][packet["refs"]["current"]]["hourly"][0]["duration_seconds"] = .5
        with self.assertRaises(ReportError): render._validate_packet(packet)

    def test_failure_cannot_keep_a_normal_total_or_hours(self):
        for field, value in (("count", 0), ("duration_seconds", 0.0), ("reconciled", True), ("hourly", [{"ts": 0}])):
            packet = sample_packet()
            result = failed_period()
            result[field] = value
            packet["clusters"][0]["periods"][packet["refs"]["current"]] = result
            with self.subTest(field=field), self.assertRaises(ReportError): render._validate_packet(packet)


if __name__ == "__main__":
    unittest.main()
