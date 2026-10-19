"""Collect only numeric DAS histograms; never request SQL or log records."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, datetime, timedelta
import hashlib
import math
from pathlib import Path
import re
import time

from .common import LABELS, TZ, ReportError, atomic_json, cli_json, read_json, safe_event

API = "DescribeSlowLogHistogramAsync"
PARSER_VERSION = 1
HOUR_MS = 3_600_000
CACHE_TTL_SECONDS = 24 * 3600
TASK_TIMEOUT_SECONDS = 240
MAX_POLLS = 40
MAX_NODES_PER_CLUSTER = 16
MAX_PERIODS = 10
_FAILURE_CATEGORIES = {
    "InventoryFailure", "InvalidInventory", "ScaleLimitExceeded", "HistogramFailure",
    "HistogramCliFailure", "HistogramResponseFailure", "HistogramStateFailure",
    "HistogramTimeout", "InvalidHistogram", "InvalidHistogramState",
    "HourlyReconciliationFailure", "HourlyVerificationIncomplete", "CollectionFailure",
    "StateWriteFailure",
}


def _now():
    return datetime.now(TZ)


def _ms(value):
    return int(value.timestamp() * 1000)


def build_windows(*, day=None, mode="daily", window_end=None, now=None):
    """Return closed requested windows without changing the DAS end boundary."""
    now = now or _now()
    if not isinstance(now, datetime) or now.utcoffset() is None:
        raise ReportError("InvalidWindow")
    now = now.astimezone(TZ)
    if mode == "daily":
        if window_end is not None or (day is not None and type(day) is not date):
            raise ReportError("InvalidWindow")
        day = day or now.date() - timedelta(days=1)
        start = datetime.combine(day, datetime.min.time(), TZ)
        end = start + timedelta(days=1)
        hours = 24
        report_key = "daily-" + start.strftime("%Y%m%d")
    elif mode == "halfday":
        if day is not None:
            raise ReportError("InvalidWindow")
        if window_end is None:
            end = now.replace(minute=0, second=0, microsecond=0)
            if end.hour >= 22:
                end = end.replace(hour=22)
            elif end.hour >= 10:
                end = end.replace(hour=10)
            else:
                end = (end - timedelta(days=1)).replace(hour=22)
        elif isinstance(window_end, datetime) and window_end.utcoffset() is not None:
            end = window_end.astimezone(TZ)
        else:
            raise ReportError("InvalidWindow")
        if end.hour not in (10, 22) or (end.minute, end.second, end.microsecond) != (0, 0, 0):
            raise ReportError("InvalidWindow")
        hours = 12
        start = end - timedelta(hours=hours)
        report_key = "halfday-" + end.strftime("%Y%m%d-%H")
    else:
        raise ReportError("InvalidWindow")
    if end > now:
        raise ReportError("InvalidWindow")
    refs = {
        "current": str(_ms(start)),
        "previous": str(_ms(start - timedelta(hours=hours))),
        "previous_day": str(_ms(start - timedelta(days=1))),
        "previous_week": str(_ms(start - timedelta(days=7))),
        "recent": [str(_ms(start - timedelta(days=i))) for i in reversed(range(7))],
    }
    starts = set(refs["recent"]) | {refs[k] for k in ("current", "previous", "previous_day", "previous_week")}
    if len(starts) > MAX_PERIODS:
        raise ReportError("ScaleLimitExceeded")
    periods = [{"key": key, "start_ms": int(key), "end_ms": int(key) + hours * HOUR_MS,
                "label": datetime.fromtimestamp(int(key) / 1000, TZ).strftime("%m-%d")}
               for key in sorted(starts, key=int)]
    return {"report_key": report_key, "mode": mode, "start_ms": _ms(start), "end_ms": _ms(end),
            "window_hours": hours, "refs": refs, "periods": periods}


def _integer(value):
    if type(value) is not int or value < 0:
        raise ReportError("InvalidHistogram")
    return value


def _number(value):
    if type(value) not in (int, float):
        raise ReportError("InvalidHistogram")
    try:
        result = float(value)
    except (OverflowError, ValueError):
        raise ReportError("InvalidHistogram") from None
    if not math.isfinite(result) or result < 0:
        raise ReportError("InvalidHistogram")
    return result


def parse_histogram(data, start_ms, end_ms, *, duration_usable):
    """Validate coverage and conservation before projecting hourly numbers."""
    if not isinstance(data, dict) or type(start_ms) is not int or type(end_ms) is not int:
        raise ReportError("InvalidHistogram")
    length = end_ms - start_ms
    if length <= 0 or length % HOUR_MS:
        raise ReportError("InvalidHistogram")
    ts, counts, durations = data.get("Ts"), data.get("Count"), data.get("Rt")
    if not isinstance(ts, list) or not isinstance(counts, list) or not ts or len(ts) != len(counts):
        raise ReportError("InvalidHistogram")
    if durations is None and not duration_usable:
        durations = [0] * len(ts)
    if not isinstance(durations, list) or len(ts) != len(durations):
        raise ReportError("InvalidHistogram")
    ts = [_integer(v) for v in ts]
    counts = [_integer(v) for v in counts]
    durations = [_number(v) for v in durations]
    total = _integer(data.get("TotalCount"))
    if ts[-1] == end_ms:
        if counts[-1] != 0 or durations[-1] != 0:
            raise ReportError("InvalidHistogram")
        ts, counts, durations = ts[:-1], counts[:-1], durations[:-1]
    if not ts or ts[0] != start_ms:
        raise ReportError("InvalidHistogram")
    step = ts[1] - ts[0] if len(ts) > 1 else length
    if step <= 0 or step > HOUR_MS or HOUR_MS % step or length // step != len(ts):
        raise ReportError("InvalidHistogram")
    if any(t != start_ms + i * step for i, t in enumerate(ts)) or sum(counts) != total:
        raise ReportError("InvalidHistogram")
    points_per_hour = HOUR_MS // step
    hourly = []
    for i in range(length // HOUR_MS):
        lo, hi = i * points_per_hour, (i + 1) * points_per_hour
        try:
            duration = _number(math.fsum(durations[lo:hi])) if duration_usable else None
        except OverflowError:
            raise ReportError("InvalidHistogram") from None
        hourly.append({"ts": start_ms + i * HOUR_MS, "count": sum(counts[lo:hi]),
                       "duration_seconds": duration})
    try:
        duration = _number(math.fsum(h["duration_seconds"] for h in hourly)) if duration_usable else None
    except OverflowError:
        raise ReportError("InvalidHistogram") from None
    return {"count": total, "duration_seconds": duration, "hourly": hourly}


def _true(value):
    return value is True or (type(value) is str and value == "true")


def _false(value):
    return value is False or (type(value) is str and value == "false")


def _histogram(config, cluster, node, start_ms, end_ms, deadline):
    args = [config["aliyun_cli"], "--profile", config["aliyun_profile"],
            "--endpoint", "das.cn-shanghai.aliyuncs.com", "--read-timeout", "90",
            "--connect-timeout", "15", "das", API, "--InstanceId", cluster["instance_id"],
            "--StartTime", str(start_ms), "--EndTime", str(end_ms)]
    if node is not None:
        args += ["--NodeId", node]
    for attempt in range(MAX_POLLS):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ReportError("HistogramTimeout")
        try:
            response = cli_json(args, timeout=min(120, remaining), error_category="HistogramFailure")
        except ReportError as exc:
            raise ReportError("HistogramTimeout" if exc.category == "CliTimeout" else "HistogramCliFailure") from None
        code = response.get("Code")
        if not ((type(code) is int and code == 200) or (type(code) is str and code == "200")) or not _true(response.get("Success")):
            raise ReportError("HistogramResponseFailure")
        result = response.get("Data")
        if not isinstance(result, dict):
            raise ReportError("InvalidHistogramState")
        state, finished = result.get("State"), result.get("IsFinish")
        if state == "FAIL":
            raise ReportError("HistogramStateFailure")
        if state == "SUCCESS" and _true(finished):
            if not isinstance(result.get("Data"), dict):
                raise ReportError("InvalidHistogram")
            return result["Data"]
        if state != "RUNNING" or not _false(finished):
            raise ReportError("InvalidHistogramState")
        if attempt + 1 < MAX_POLLS:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            time.sleep(min(1, remaining))
    raise ReportError("HistogramTimeout")


def _inventory(config, cluster):
    if cluster["engine"] == "postgres":
        return [None]
    try:
        data = cli_json([config["aliyun_cli"], "--profile", config["aliyun_profile"], "polardb",
                         "DescribeDBClusterAttribute", "--DBClusterId", cluster["instance_id"],
                         "--RegionId", config["aliyun_region"]], timeout=120, error_category="InventoryFailure")
    except Exception:
        raise ReportError("InventoryFailure") from None
    rows = data.get("DBNodes")
    if not isinstance(rows, list) or not rows:
        raise ReportError("InvalidInventory")
    if len(rows) > MAX_NODES_PER_CLUSTER:
        raise ReportError("ScaleLimitExceeded")
    nodes = []
    for row in rows:
        if not isinstance(row, dict) or row.get("DBNodeRole") not in ("Writer", "Reader"):
            raise ReportError("InvalidInventory")
        node = row.get("DBNodeId")
        if not isinstance(node, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", node) or node in nodes:
            raise ReportError("InvalidInventory")
        nodes.append(node)
    return sorted(nodes)


def _identity(cluster, node):
    # This identifies cache scope, not a credential. No upstream strings are saved.
    return hashlib.sha256((cluster["engine"] + ":" + cluster["instance_id"] + ":" + (node or "cluster")).encode()).hexdigest()


def _cached(path, identity, period, usable, now):
    try:
        cached = read_json(path)
        if not isinstance(cached, dict) or set(cached) != {
            "api", "parser_version", "identity", "start_ms", "end_ms", "fetched_at", "result", "reconciliation"
        }:
            return None
        if cached["api"] != API or cached["parser_version"] != PARSER_VERSION or cached["identity"] != identity:
            return None
        if cached["start_ms"] != period["start_ms"] or cached["end_ms"] != period["end_ms"]:
            return None
        fetched = datetime.fromisoformat(cached["fetched_at"])
        if fetched.utcoffset() is None or not 0 <= (now - fetched).total_seconds() < CACHE_TTL_SECONDS:
            return None
        result, check = cached["result"], cached["reconciliation"]
        if not isinstance(result, dict) or set(result) != {"count", "duration_seconds", "hourly", "reconciled"} or result["reconciled"] is not True:
            return None
        rows = result["hourly"]
        if not isinstance(rows, list) or len(rows) != (period["end_ms"] - period["start_ms"]) // HOUR_MS:
            return None
        for i, row in enumerate(rows):
            if not isinstance(row, dict) or set(row) != {"ts", "count", "duration_seconds"}:
                return None
            if row["ts"] != period["start_ms"] + i * HOUR_MS:
                return None
            _integer(row["count"])
            if usable:
                _number(row["duration_seconds"])
            elif row["duration_seconds"] is not None:
                return None
        if _integer(result["count"]) != sum(h["count"] for h in rows):
            return None
        if usable:
            if not math.isclose(_number(result["duration_seconds"]), math.fsum(h["duration_seconds"] for h in rows), rel_tol=1e-9, abs_tol=1e-6):
                return None
        elif result["duration_seconds"] is not None:
            return None
        expected = max(rows, key=lambda h: h["count"])
        if not isinstance(check, dict) or set(check) != {"ts", "count", "duration_seconds"}:
            return None
        if check["ts"] != expected["ts"] or _integer(check["count"]) != expected["count"]:
            return None
        if usable:
            if not math.isclose(_number(check["duration_seconds"]), expected["duration_seconds"],
                                rel_tol=1e-9, abs_tol=1e-6):
                return None
        elif check["duration_seconds"] is not None:
            return None
        return result
    except Exception:
        return None


def _collect_node_period(config, cluster, node, period, *, refresh, now):
    usable = cluster["engine"] == "mysql"
    identity = _identity(cluster, node)
    filename = f"{period['start_ms']}-{period['end_ms']}.json"
    path = Path(config["state_dir"]) / "collect-cache" / identity / filename
    if not refresh:
        cached = _cached(path, identity, period, usable, now)
        if cached is not None:
            return cached
    deadline = time.monotonic() + TASK_TIMEOUT_SECONDS
    raw = _histogram(config, cluster, node, period["start_ms"], period["end_ms"], deadline)
    result = parse_histogram(raw, period["start_ms"], period["end_ms"], duration_usable=usable)
    chosen = max(result["hourly"], key=lambda h: h["count"])
    try:
        hour = _histogram(config, cluster, node, chosen["ts"], chosen["ts"] + HOUR_MS, deadline)
        check = parse_histogram(hour, chosen["ts"], chosen["ts"] + HOUR_MS, duration_usable=usable)
    except Exception:
        raise ReportError("HourlyVerificationIncomplete") from None
    if check["count"] != chosen["count"] or (usable and not math.isclose(
        check["duration_seconds"], chosen["duration_seconds"], rel_tol=1e-9, abs_tol=1e-6
    )):
        raise ReportError("HourlyReconciliationFailure")
    result["reconciled"] = True
    atomic_json(path, {"api": API, "parser_version": PARSER_VERSION, "identity": identity,
                       "start_ms": period["start_ms"], "end_ms": period["end_ms"],
                       "fetched_at": now.isoformat(), "result": result,
                       "reconciliation": {"ts": chosen["ts"], "count": check["count"],
                                          "duration_seconds": check["duration_seconds"]}})
    return result


def _failed(category):
    return {"status": "failed", "category": category if category in _FAILURE_CATEGORIES else "CollectionFailure",
            "count": None, "duration_seconds": None, "hourly": [], "reconciled": False}


def _aggregate(results, usable):
    hourly = []
    for i, first in enumerate(results[0]["hourly"]):
        durations = [r["hourly"][i]["duration_seconds"] for r in results]
        hourly.append({"ts": first["ts"], "count": sum(r["hourly"][i]["count"] for r in results),
                       "duration_seconds": _number(math.fsum(durations)) if usable else None})
    return {"status": "complete", "category": None, "count": sum(h["count"] for h in hourly),
            "duration_seconds": _number(math.fsum(h["duration_seconds"] for h in hourly)) if usable else None,
            "hourly": hourly, "reconciled": True}


def collect_report(config, *, day=None, mode="daily", window_end=None, refresh=False):
    """Collect a complete numeric packet; failures have fixed categories only."""
    now = _now()
    windows = build_windows(day=day, mode=mode, window_end=window_end, now=now)
    workers = config.get("workers", 1)
    if type(workers) is not int or not 1 <= workers <= 4:
        raise ReportError("InvalidConfig")
    packet = {"schema_version": 1, **windows, "generated_at": now.isoformat(), "clusters": []}
    jobs, nodes_by_cluster, failures, collected = [], {}, {}, {}
    for cluster in config["clusters"]:
        key, usable = cluster["key"], cluster["engine"] == "mysql"
        output = {"key": key, "label": LABELS[key], "engine": cluster["engine"],
                  "scope": "current_nodes_all_accounts" if usable else "all_logs_business_scope_unverified",
                  "duration_usable": usable, "node_count": 0, "inventory_changed": False, "periods": {}}
        packet["clusters"].append(output)
        try:
            nodes = _inventory(config, cluster)
            nodes_by_cluster[key] = nodes
            output["node_count"] = len(nodes)
            snapshot = Path(config["state_dir"]) / "collect-inventory" / (key + ".json")
            identity = _identity(cluster, None)
            current = {"identity": identity, "nodes": nodes}
            try:
                before = read_json(snapshot)
            except Exception:
                before = None
            output["inventory_changed"] = before is not None and before != current
            atomic_json(snapshot, current)
            for period in windows["periods"]:
                for node in nodes:
                    jobs.append((cluster, node, period))
        except Exception as exc:
            category = exc.category if isinstance(exc, ReportError) else "InventoryFailure"
            for period in windows["periods"]:
                failures[(key, period["key"])] = _failed(category)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        future_jobs = {
            pool.submit(_collect_node_period, config, cluster, node, period,
                        refresh=refresh or period["key"] == windows["refs"]["current"], now=now): (cluster, node, period)
            for cluster, node, period in jobs
        }
        for done, future in enumerate(as_completed(future_jobs), 1):
            cluster, node, period = future_jobs[future]
            pair = (cluster["key"], period["key"])
            try:
                collected.setdefault(pair, []).append(future.result())
            except Exception as exc:
                category = exc.category if isinstance(exc, ReportError) else "CollectionFailure"
                failures[pair] = _failed(category)
                safe_event("CollectNodeFailed", cluster=cluster["key"], period=period["key"],
                           node_index=nodes_by_cluster[cluster["key"]].index(node),
                           category=failures[pair]["category"])
            safe_event("CollectProgress", completed=done, total=len(jobs))
    for cluster in packet["clusters"]:
        for period in windows["periods"]:
            pair = (cluster["key"], period["key"])
            if pair in failures:
                cluster["periods"][period["key"]] = failures[pair]
            else:
                results = collected.get(pair, [])
                if len(results) != len(nodes_by_cluster.get(cluster["key"], [])) or not results:
                    cluster["periods"][period["key"]] = _failed("CollectionFailure")
                    continue
                try:
                    cluster["periods"][period["key"]] = _aggregate(results, cluster["duration_usable"])
                except Exception:
                    cluster["periods"][period["key"]] = _failed("InvalidHistogram")
    return packet
