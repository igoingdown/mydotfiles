"""Synthetic collector checks. These tests never call a real CLI or service."""
from datetime import date, datetime, timedelta
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

from . import collect
from .common import ReportError, TZ

NOW = datetime(2025, 2, 12, 11, tzinfo=TZ)
DAY = date(2025, 2, 11)
START = int(datetime(2025, 2, 11, tzinfo=TZ).timestamp()) * 1000
SYNTHETIC_PRIVATE = "TEST_ONLY_private_payload"


def histogram(start=START, hours=24, *, step=300_000, boundary=True, multiplier=1):
    points = hours * collect.HOUR_MS // step
    count = step // 60_000 * multiplier
    result = {"Ts": [start + i * step for i in range(points)], "Count": [count] * points,
              "Rt": [count / 2] * points, "TotalCount": count * points,
              "IgnoredExtra": SYNTHETIC_PRIVATE}
    if boundary:
        result["Ts"].append(start + hours * collect.HOUR_MS)
        result["Count"].append(0)
        result["Rt"].append(0)
    return result


def envelope(data=None, *, state="SUCCESS", success=True, finished=True, code="200"):
    return {"Code": code, "Success": success,
            "Message": SYNTHETIC_PRIVATE,
            "Data": {"State": state, "IsFinish": finished,
                     "Data": data if data is not None else histogram()}}


def config(directory, *, workers=1):
    return {"state_dir": directory, "aliyun_cli": "fixture-aliyun", "aliyun_profile": "fixture",
            "aliyun_region": "fixture-region", "workers": workers,
            "clusters": [{"key": "primary_mysql", "instance_id": "pc-fixturemysql", "engine": "mysql"},
                         {"key": "postgres", "instance_id": "pc-fixturepg", "engine": "postgres"}]}


class FixtureCLI:
    def __init__(self):
        self.calls = []
        self.mismatch = False
        self.fail_reader = False
        self.hour_failure = False
        self.duration_difference = 0
        self.multiplier = 1
        self.inventory_nodes = ["fixture-writer", "fixture-reader"]

    def __call__(self, args, **kwargs):
        self.calls.append((args, kwargs))
        if "DescribeDBClusterAttribute" in args:
            return {"DBNodes": [{"DBNodeId": node, "DBNodeRole": "Writer" if i == 0 else "Reader",
                                 "IgnoredExtra": SYNTHETIC_PRIVATE}
                                for i, node in enumerate(self.inventory_nodes)], "IgnoredExtra": SYNTHETIC_PRIVATE}
        if collect.API not in args:
            raise AssertionError("Only safe aggregate operations may be called")
        start, end = int(args[args.index("--StartTime") + 1]), int(args[args.index("--EndTime") + 1])
        # This is a regression guard for losing the last minute through -1ms.
        if start % collect.HOUR_MS or end % collect.HOUR_MS:
            raise AssertionError("Exact hourly boundaries are required")
        if self.fail_reader and "fixture-reader" in args:
            raise RuntimeError(SYNTHETIC_PRIVATE)
        hours = (end - start) // collect.HOUR_MS
        if hours == 1 and self.hour_failure:
            raise ReportError("CliTimeout")
        result = histogram(start, hours, step=60_000 if hours == 1 else 300_000, multiplier=self.multiplier)
        if hours == 1 and self.mismatch:
            result["Count"][0] += 1
            result["TotalCount"] += 1
        if hours == 1:
            result["Rt"][0] += self.duration_difference
        if "pc-fixturepg" in args:
            # Background duration must never escape into cache or packet.
            result["Rt"] = [123456789.0 if count else 0 for count in result["Count"]]
        return envelope(result)


class BoundaryLossCLI(FixtureCLI):
    """Model the observed last-minute loss for an end boundary minus 1ms."""

    def __call__(self, args, **kwargs):
        if "--EndTime" not in args:
            return super().__call__(args, **kwargs)
        args = list(args)
        index = args.index("--EndTime") + 1
        value = int(args[index])
        shifted = value % collect.HOUR_MS != 0
        if shifted:
            args[index] = str(value + 1)
        response = super().__call__(args, **kwargs)
        if shifted:
            raw = response["Data"]["Data"]
            raw["Count"][-2] -= 1
            raw["Rt"][-2] = max(0, raw["Rt"][-2] - 0.5)
            raw["TotalCount"] -= 1
        return response


class WindowTests(unittest.TestCase):
    def test_daily_eight_days_and_refs(self):
        windows = collect.build_windows(day=DAY, now=NOW)
        self.assertEqual(len(windows["periods"]), 8)
        self.assertEqual(windows["start_ms"], START)
        self.assertEqual(windows["end_ms"], START + 24 * collect.HOUR_MS)
        self.assertEqual(windows["refs"]["previous"], windows["refs"]["previous_day"])
        self.assertEqual(windows["refs"]["recent"][-1], str(START))
        self.assertEqual(len(windows["refs"]["recent"]), 7)

    def test_halfday_includes_adjacent_and_same_hour_days(self):
        windows = collect.build_windows(mode="halfday", now=NOW)
        self.assertEqual(windows["report_key"], "halfday-20250212-10")
        self.assertEqual(windows["window_hours"], 12)
        self.assertEqual(len(windows["periods"]), 9)
        current = int(windows["refs"]["current"])
        self.assertEqual(int(windows["refs"]["previous"]), current - 12 * collect.HOUR_MS)
        self.assertEqual(int(windows["refs"]["previous_day"]), current - 24 * collect.HOUR_MS)
        self.assertEqual({(current - int(k)) // collect.HOUR_MS for k in windows["refs"]["recent"]},
                         {0, 24, 48, 72, 96, 120, 144})

    def test_invalid_or_unclosed_windows(self):
        cases = [{"day": NOW.date()}, {"mode": "other"},
                 {"mode": "halfday", "window_end": NOW.replace(tzinfo=None)},
                 {"mode": "halfday", "window_end": NOW},
                 {"mode": "halfday", "window_end": NOW.replace(hour=22)},
                 {"mode": "halfday", "window_end": NOW.replace(hour=10, microsecond=1)}]
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ReportError):
                collect.build_windows(now=NOW, **case)


class HistogramTests(unittest.TestCase):
    def parse(self, value, hours=24, usable=True):
        return collect.parse_histogram(value, START, START + hours * collect.HOUR_MS, duration_usable=usable)

    def test_conservation_and_boundary_projection(self):
        result = self.parse(histogram())
        self.assertEqual(result["count"], 1440)
        self.assertEqual(result["duration_seconds"], 720)
        self.assertEqual(len(result["hourly"]), 24)
        self.assertEqual(result["hourly"][0], {"ts": START, "count": 60, "duration_seconds": 30})
        self.assertNotIn(SYNTHETIC_PRIVATE, json.dumps(result))

    def test_postgres_durations_are_null(self):
        value = histogram()
        value["Rt"][0] = 123456789.0
        result = self.parse(value, usable=False)
        self.assertIsNone(result["duration_seconds"])
        self.assertTrue(all(h["duration_seconds"] is None for h in result["hourly"]))
        self.assertNotIn("123456789", json.dumps(result))

    def test_rejects_incomplete_or_malformed_arrays(self):
        cases = []
        for field in ("Ts", "Count", "Rt"):
            value = histogram(); value[field].pop(5); cases.append(value)
        value = histogram(); value["Ts"][2] = value["Ts"][1]; cases.append(value)
        value = histogram(); value["Ts"] = list(reversed(value["Ts"])); cases.append(value)
        value = histogram(); value["Ts"] = [t + 1 for t in value["Ts"]]; cases.append(value)
        value = histogram(); value["TotalCount"] += 1; cases.append(value)
        value = histogram(); value["Count"][0] = True; cases.append(value)
        value = histogram(); value["Count"][0] = 5.0; cases.append(value)
        value = histogram(); value["Count"][0] = -1; cases.append(value)
        value = histogram(); value["Rt"][0] = float("nan"); cases.append(value)
        value = histogram(); value["Rt"][0] = float("inf"); cases.append(value)
        value = histogram(); value["Count"][-1] = 1; value["TotalCount"] += 1; cases.append(value)
        value = histogram(); value["Rt"][-1] = 1; cases.append(value)
        value = histogram(step=7200_000); cases.append(value)
        for index, value in enumerate(cases):
            with self.subTest(index=index), self.assertRaises(ReportError):
                self.parse(value)

    def test_true_zero_is_complete(self):
        value = histogram(multiplier=0)
        self.assertEqual(self.parse(value)["count"], 0)


class AsyncTests(unittest.TestCase):
    def call(self):
        return collect._histogram(config("fixture-state"), config("fixture-state")["clusters"][0],
                                  "fixture-node", START, START + 24 * collect.HOUR_MS,
                                  time.monotonic() + 10)

    def test_accepts_documented_boolean_and_string_flags(self):
        for flag in (True, "true"):
            with self.subTest(flag=flag), patch.object(collect, "cli_json", return_value=envelope(success=flag, finished=flag)):
                self.assertEqual(self.call()["TotalCount"], 1440)

    def test_false_or_inconsistent_success_is_never_truthy(self):
        values = [envelope(success="false"), envelope(success=1), envelope(success="True"),
                  envelope(code=True), envelope(state="FAIL"), envelope(state="UNKNOWN"),
                  envelope(finished="false"), envelope(finished=1), envelope(state="RUNNING")]
        for value in values:
            with self.subTest(value=value), patch.object(collect, "cli_json", return_value=value), self.assertRaises(ReportError):
                self.call()

    def test_running_polls_until_success(self):
        with patch.object(collect, "cli_json", side_effect=[envelope(state="RUNNING", finished="false"), envelope()]) as cli, patch.object(collect.time, "sleep"):
            self.call()
            self.assertEqual(cli.call_count, 2)

    def test_failure_stage_categories_are_fixed(self):
        for response, category in ((envelope(code="403"), "HistogramResponseFailure"),
                                   (envelope(state="FAIL"), "HistogramStateFailure")):
            with self.subTest(category=category), patch.object(collect, "cli_json", return_value=response):
                with self.assertRaisesRegex(ReportError, "^" + category + "$"):
                    self.call()
        with patch.object(collect, "cli_json", side_effect=ReportError("CliInvalidJSON")):
            with self.assertRaisesRegex(ReportError, "^HistogramCliFailure$"):
                self.call()
        with patch.object(collect, "cli_json", side_effect=ReportError("CliTimeout")):
            with self.assertRaisesRegex(ReportError, "^HistogramTimeout$"):
                self.call()

    def test_polling_is_bounded(self):
        with patch.object(collect, "cli_json", return_value=envelope(state="RUNNING", finished=False)), patch.object(collect.time, "sleep"), patch.object(collect, "MAX_POLLS", 2):
            with self.assertRaisesRegex(ReportError, "^HistogramTimeout$"):
                self.call()


class CollectorTests(unittest.TestCase):
    def collect(self, directory, fixture, **kwargs):
        captured = io.StringIO()
        with patch.object(collect, "_now", return_value=NOW), patch.object(collect, "cli_json", side_effect=fixture), redirect_stdout(captured):
            result = collect.collect_report(config(directory), day=DAY, **kwargs)
        self.assertNotIn(SYNTHETIC_PRIVATE, captured.getvalue())
        self.events = [json.loads(line) for line in captured.getvalue().splitlines()]
        return result

    def test_complete_packet_cache_and_no_private_strings(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FixtureCLI()
            result = self.collect(directory, fixture)
            self.assertEqual(len(result["clusters"]), 2)
            for cluster in result["clusters"]:
                self.assertTrue(all(p["status"] == "complete" and p["reconciled"] for p in cluster["periods"].values()))
            mysql, pg = result["clusters"]
            current = result["refs"]["current"]
            self.assertEqual(mysql["periods"][current]["count"], 2880)
            self.assertEqual(pg["periods"][current]["count"], 1440)
            self.assertIsNone(pg["periods"][current]["duration_seconds"])
            serialized = json.dumps(result)
            self.assertNotIn("fixture-writer", serialized)
            self.assertNotIn("pc-fixturemysql", serialized)
            for path in Path(directory).rglob("*.json"):
                text = path.read_text()
                self.assertNotIn(SYNTHETIC_PRIVATE, text)
                self.assertNotIn("123456789", text)
                self.assertNotIn("Message", text)
            calls = len(fixture.calls)
            self.collect(directory, fixture)
            self.assertEqual(len(fixture.calls) - calls, 7)  # inventory + three current nodes x two requests
            calls = len(fixture.calls)
            self.collect(directory, fixture, refresh=True)
            self.assertEqual(len(fixture.calls) - calls, 49)

    def test_missing_one_mysql_node_fails_whole_cluster_window(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FixtureCLI(); fixture.fail_reader = True
            result = self.collect(directory, fixture)
            for period in result["clusters"][0]["periods"].values():
                self.assertEqual(period["status"], "failed")
                self.assertIsNone(period["count"])
                self.assertEqual(period["hourly"], [])
            self.assertTrue(all(p["status"] == "complete" for p in result["clusters"][1]["periods"].values()))
            self.assertNotIn(SYNTHETIC_PRIVATE, json.dumps(result))
            failures = [event for event in self.events if event["event"] == "CollectNodeFailed"]
            self.assertEqual(len(failures), 8)
            for event in failures:
                self.assertEqual(set(event), {"event", "cluster", "period", "node_index", "category"})
                self.assertEqual(event["cluster"], "primary_mysql")
                self.assertEqual(event["node_index"], 0)  # sorted frozen inventory: reader, writer
                self.assertEqual(event["category"], "CollectionFailure")
                self.assertIn(event["period"], {period["key"] for period in result["periods"]})

    def test_mismatch_is_not_successfully_cached_even_for_postgres(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FixtureCLI(); fixture.mismatch = True
            result = self.collect(directory, fixture)
            for cluster in result["clusters"]:
                for period in cluster["periods"].values():
                    self.assertEqual(period["category"], "HourlyReconciliationFailure")
            self.assertEqual(list((Path(directory) / "collect-cache").rglob("*.json")), [])

    def test_hour_request_failure_is_not_called_data_conflict(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FixtureCLI(); fixture.hour_failure = True
            result = self.collect(directory, fixture)
            for cluster in result["clusters"]:
                self.assertTrue(all(p["category"] == "HourlyVerificationIncomplete" for p in cluster["periods"].values()))

    def test_duration_difference_is_checked_with_documented_tolerance(self):
        for difference, complete in ((1e-7, True), (1e-3, False)):
            with self.subTest(difference=difference), tempfile.TemporaryDirectory() as directory:
                fixture = FixtureCLI(); fixture.duration_difference = difference
                result = self.collect(directory, fixture)
                self.assertTrue(all((p["status"] == "complete") == complete for p in result["clusters"][0]["periods"].values()))
                if complete:
                    calls = len(fixture.calls)
                    self.collect(directory, fixture)
                    self.assertEqual(len(fixture.calls) - calls, 7)

    def test_exact_end_boundary_keeps_last_minute(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.collect(directory, BoundaryLossCLI())
            self.assertTrue(all(p["status"] == "complete" for c in result["clusters"] for p in c["periods"].values()))
            self.assertEqual(result["clusters"][0]["periods"][result["refs"]["current"]]["count"], 2880)

    def test_zero_volume_reconciles_first_hour(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FixtureCLI(); fixture.multiplier = 0
            result = self.collect(directory, fixture)
            self.assertTrue(all(p["status"] == "complete" and p["count"] == 0 for c in result["clusters"] for p in c["periods"].values()))
            histogram_calls = [args for args, _ in fixture.calls if collect.API in args]
            for broad, narrow in zip(histogram_calls[::2], histogram_calls[1::2]):
                self.assertEqual(broad[broad.index("--StartTime") + 1], narrow[narrow.index("--StartTime") + 1])

    def test_expired_cache_requeries_historical_windows(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FixtureCLI()
            self.collect(directory, fixture)
            for path in (Path(directory) / "collect-cache").rglob("*.json"):
                value = json.loads(path.read_text()); value["fetched_at"] = (NOW - timedelta(hours=24)).isoformat()
                path.write_text(json.dumps(value))
            calls = len(fixture.calls)
            self.collect(directory, fixture)
            self.assertEqual(len(fixture.calls) - calls, 49)

    def test_inventory_change_is_visible_and_node_set_is_frozen(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FixtureCLI()
            self.collect(directory, fixture)
            fixture.inventory_nodes = ["fixture-writer"]
            result = self.collect(directory, fixture)
            self.assertTrue(result["clusters"][0]["inventory_changed"])
            self.assertEqual(result["clusters"][0]["node_count"], 1)

    def test_inventory_limit_rejects_without_histogram_calls(self):
        fixture = FixtureCLI(); fixture.inventory_nodes = ["fixture-node" + str(i) for i in range(17)]
        cfg = config("fixture-state")
        with patch.object(collect, "cli_json", side_effect=fixture), self.assertRaisesRegex(ReportError, "^ScaleLimitExceeded$"):
            collect._inventory(cfg, cfg["clusters"][0])
        self.assertEqual(len(fixture.calls), 1)

    def test_halfday_also_reconciles_and_zero_chooses_first_hour(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = FixtureCLI()
            with patch.object(collect, "_now", return_value=NOW), patch.object(collect, "cli_json", side_effect=fixture), redirect_stdout(io.StringIO()):
                result = collect.collect_report(config(directory), mode="halfday")
            self.assertEqual(len(result["periods"]), 9)
            for cluster in result["clusters"]:
                self.assertTrue(all(p["reconciled"] for p in cluster["periods"].values()))
                self.assertTrue(all(len(p["hourly"]) == 12 for p in cluster["periods"].values()))


if __name__ == "__main__":
    unittest.main()
