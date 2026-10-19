"""Render an allowlisted numeric packet; never accept logs or query text."""
from __future__ import annotations

import csv
from collections import Counter
from datetime import datetime
from html import escape
import math
from pathlib import Path
import re

from .common import LABELS, TZ, ReportError

HOUR = 3_600_000
DAY = 24 * HOUR
_KEYS = tuple(LABELS)
_PACKET_FIELDS = {"schema_version", "report_key", "mode", "start_ms", "end_ms",
                  "window_hours", "generated_at", "refs", "periods", "clusters"}
_CLUSTER_FIELDS = {"key", "label", "engine", "scope", "duration_usable", "node_count",
                   "inventory_changed", "periods"}
_RESULT_FIELDS = {"status", "category", "count", "duration_seconds", "hourly", "reconciled"}
_PERIOD_LABELS = {"昨日", "前天", "上周同日", "本窗", "前一日同窗", "上周同窗", "上一窗", "前一窗"}
_COL_WIDTHS = (100, 80, 120, 120, 140, 260)
_STYLES = (("current", "#1769b5", "-"), ("previous_day", "#747b84", "--"),
           ("previous_week", "#dd7615", "-."))
_FAILURE_LABELS = {
    "InventoryFailure": "节点清单获取未完成", "InvalidInventory": "节点清单校验未通过",
    "ScaleLimitExceeded": "采集范围超过上限", "HistogramFailure": "慢日志统计获取未完成",
    "HistogramCliFailure": "采集命令失败", "HistogramResponseFailure": "统计接口返回失败",
    "HistogramStateFailure": "异步统计任务失败",
    "HistogramTimeout": "慢日志统计等待超时", "InvalidHistogram": "统计完整性校验未通过",
    "InvalidHistogramState": "统计状态未确认完成", "HourlyReconciliationFailure": "小时口径对账不一致",
    "HourlyVerificationIncomplete": "独立小时核验未完成", "CollectionFailure": "采集未完成",
    "StateWriteFailure": "安全缓存写入未完成",
}


def _require(condition):
    if not condition:
        raise ReportError("InvalidPacket")


def _fields(value, names):
    _require(isinstance(value, dict) and set(value) == names)


def _integer(value):
    _require(type(value) is int and 0 <= value <= 2**63 - 1)
    return value


def _number(value):
    _require(type(value) in (int, float))
    try:
        _require(math.isfinite(value) and value >= 0)
    except (OverflowError, TypeError, ValueError):
        raise ReportError("InvalidPacket") from None
    return value


def _date(milliseconds):
    return datetime.fromtimestamp(milliseconds / 1000, TZ)


def _validate_packet(packet):
    """Validate recursively before creating any report artifact."""
    try:
        _fields(packet, _PACKET_FIELDS)
        _require(type(packet["schema_version"]) is int and packet["schema_version"] == 1)
        _require(packet["mode"] in ("daily", "halfday"))
        hours = 24 if packet["mode"] == "daily" else 12
        _require(type(packet["window_hours"]) is int and packet["window_hours"] == hours)
        start, end = _integer(packet["start_ms"]), _integer(packet["end_ms"])
        _require(start % HOUR == 0 and end - start == hours * HOUR)
        first, last = _date(start), _date(end)
        _require(first.hour == 0 if hours == 24 else last.hour in (10, 22))
        expected_key = ("daily-" + first.strftime("%Y%m%d") if hours == 24 else
                        "halfday-" + last.strftime("%Y%m%d-%H"))
        _require(packet["report_key"] == expected_key)
        _require(isinstance(packet["generated_at"], str))
        _require(datetime.fromisoformat(packet["generated_at"]).utcoffset() is not None)

        refs = packet["refs"]
        _fields(refs, {"current", "previous", "previous_day", "previous_week", "recent"})
        expected = {"current": str(start), "previous": str(start - hours * HOUR),
                    "previous_day": str(start - DAY), "previous_week": str(start - 7 * DAY),
                    "recent": [str(start - i * DAY) for i in range(6, -1, -1)]}
        _require(refs == expected)
        required = set(refs["recent"]) | {refs[k] for k in ("current", "previous", "previous_day", "previous_week")}
        periods = packet["periods"]
        _require(isinstance(periods, list) and 1 <= len(periods) <= 10)
        keys = []
        for period in periods:
            _fields(period, {"key", "start_ms", "end_ms", "label"})
            ps, pe = _integer(period["start_ms"]), _integer(period["end_ms"])
            _require(ps % HOUR == 0 and pe - ps == hours * HOUR)
            _require(period["key"] == str(ps))
            label = period["label"]
            _require(isinstance(label, str) and
                     (label in _PERIOD_LABELS or label == _date(ps).strftime("%m-%d")))
            keys.append(period["key"])
        _require(len(keys) == len(set(keys)) and set(keys) == required)
        _require(keys == sorted(keys, key=int))

        clusters = packet["clusters"]
        _require(isinstance(clusters, list) and 1 <= len(clusters) <= 3)
        seen = set()
        for cluster in clusters:
            _fields(cluster, _CLUSTER_FIELDS)
            key = cluster["key"]
            _require(isinstance(key, str) and key in LABELS and key not in seen)
            seen.add(key)
            pg = key == "postgres"
            _require(cluster["label"] == LABELS[key])
            _require(cluster["engine"] == ("postgres" if pg else "mysql"))
            _require(cluster["scope"] == ("all_logs_business_scope_unverified" if pg else "current_nodes_all_accounts"))
            _require(type(cluster["duration_usable"]) is bool and cluster["duration_usable"] == (not pg))
            _require(_integer(cluster["node_count"]) <= 16)
            _require(type(cluster["inventory_changed"]) is bool)
            _fields(cluster["periods"], required)
            for period_key, result in cluster["periods"].items():
                _fields(result, _RESULT_FIELDS)
                _require(result["status"] in ("complete", "failed"))
                _require(result["category"] is None or (isinstance(result["category"], str) and
                         re.fullmatch(r"[A-Z][A-Za-z0-9]{0,70}", result["category"]) is not None))
                _require(type(result["reconciled"]) is bool and isinstance(result["hourly"], list))
                if result["status"] == "failed":
                    _require(result["count"] is None and result["duration_seconds"] is None and
                             result["hourly"] == [] and result["reconciled"] is False)
                    continue
                _require(result["reconciled"] is True and result["category"] is None)
                _require(cluster["node_count"] > 0)
                _integer(result["count"])
                if pg:
                    _require(result["duration_seconds"] is None)
                else:
                    _number(result["duration_seconds"])
                _require(len(result["hourly"]) == hours)
                for i, point in enumerate(result["hourly"]):
                    _fields(point, {"ts", "count", "duration_seconds"})
                    _require(_integer(point["ts"]) == int(period_key) + i * HOUR)
                    _integer(point["count"])
                    if pg:
                        _require(point["duration_seconds"] is None)
                    else:
                        _number(point["duration_seconds"])
                _require(sum(p["count"] for p in result["hourly"]) == result["count"])
                if not pg:
                    total = math.fsum(p["duration_seconds"] for p in result["hourly"])
                    _require(math.isclose(total, result["duration_seconds"], abs_tol=1e-6, rel_tol=1e-9))
    except ReportError:
        raise
    except (KeyError, TypeError, ValueError, OverflowError, OSError):
        raise ReportError("InvalidPacket") from None
    return packet


def _cluster(packet, key):
    return next((c for c in packet["clusters"] if c["key"] == key), None)


def _result(cluster, key):
    if cluster is None:
        return None
    result = cluster["periods"][key]
    return result if result["status"] == "complete" else None


def _value(cluster, period_key, field):
    result = _result(cluster, period_key)
    return result[field] if result is not None else None


def _fmt(value, field):
    if value is None:
        return "缺失"
    if field == "count":
        return f"{value:,}"
    if 0 < value < .001:
        return "不足0.001"
    if 0 < value < 1:
        return f"{value:.3f}".rstrip("0")
    return f"{value:,.1f}"


def _change(value, baseline):
    if value is None or baseline is None:
        return "无可比数据"
    if value == baseline:
        return "持平"
    if baseline == 0:
        return "由零增加"
    percent = abs((value - baseline) / baseline) * 100
    if percent < .1:
        return ("增加" if value > baseline else "减少") + "不足0.1%"
    return ("增加" if value > baseline else "减少") + f"{percent:.1f}%"


def _legend(packet):
    return ("昨日", "前天", "上周同日") if packet["mode"] == "daily" else ("本窗", "前一日同窗", "上周同窗")


def _missing(packet):
    return any(c["periods"][p["key"]]["status"] != "complete"
               for c in packet["clusters"] for p in packet["periods"]) or len(packet["clusters"]) < 3


def _window(packet):
    return f"{_date(packet['start_ms']):%Y-%m-%d %H:%M} 至 {_date(packet['end_ms']):%Y-%m-%d %H:%M}"


def _title(packet):
    title = "慢查询日报" if packet["mode"] == "daily" else "慢查询十二小时巡检"
    return title + " " + _date(packet["start_ms"]).strftime("%Y-%m-%d") + ("｜数据不完整" if _missing(packet) else "")


def _scope(packet):
    lines = [
        "统计范围：主、次 MySQL 为当前节点集合的全部账号慢日志，包含复制及管理工具；所有对照采用同一范围。仅覆盖当前节点，不覆盖已退役节点；节点角色只代表当前清单。",
        "PostgreSQL 次数为全量慢日志计数，业务与后台未分离；业务耗时待核，不加入 MySQL 耗时，也不据此判断业务变化。",
        "缺失表示数据或独立小时核验未完成，不代表零；真实零值才画零。累计耗时可由并发执行累加，不能直接当作健康结论；缺少全部查询次数，不判断查询效率。",
    ]
    if packet["mode"] == "halfday":
        lines.append("十二小时口径：对照为前一日相同时段、上周相同时段；七期趋势为过去七个同类窗口，不代表七个完整自然日。")
    else:
        lines.append("日窗口径：昨日完整北京时间自然日；对照为前天及上周同日，七日趋势包含昨日。")
    for key in _KEYS:
        cluster = _cluster(packet, key)
        if cluster is None:
            lines.append(f"{LABELS[key]}：未配置，未作统计。")
        elif cluster["inventory_changed"]:
            lines.append(f"{LABELS[key]}：节点清单较上轮变化，历史对照仅覆盖本轮当前节点，请注意可比范围。")
    return lines


def _summary(packet):
    refs = packet["refs"]
    legends = _legend(packet)
    lines = []
    for key in _KEYS[:2]:
        cluster = _cluster(packet, key)
        if cluster is None:
            lines.append(f"{LABELS[key]}：未配置，未作统计。")
            continue
        current = _result(cluster, refs["current"])
        if current is None:
            lines.append(f"{LABELS[key]}：当前窗口数据缺失，次数、耗时及变化暂不能判断。")
            continue
        line = (f"{LABELS[key]}：慢日志 {_fmt(current['count'], 'count')} 次，"
                f"累计耗时 {_fmt(current['duration_seconds'], 'duration_seconds')} 秒。")
        for ref, label in (("previous_day", legends[1]), ("previous_week", legends[2])):
            baseline = _result(cluster, refs[ref])
            if baseline is None:
                line += f"较{label}无可比数据；"
            else:
                line += (f"较{label}次数{_change(current['count'], baseline['count'])}、"
                         f"耗时{_change(current['duration_seconds'], baseline['duration_seconds'])}；")
        lines.append(line.rstrip("；") + "。")
    peaks = []
    for key in _KEYS[:2]:
        cluster = _cluster(packet, key)
        current = _result(cluster, refs["current"])
        if current is not None:
            peaks += [(p["count"], key, p["ts"]) for p in current["hourly"]]
    if peaks and max(p[0] for p in peaks) > 0:
        count, key, stamp = max(peaks, key=lambda p: p[0])
        third = f"次数最高的小时：{LABELS[key]} {_date(stamp):%m-%d %H}:00 至 {_date(stamp + HOUR):%H}:00，{count:,} 次。"
    elif peaks:
        third = "已完成的 MySQL 集群当前窗口慢日志次数均为零。"
    else:
        third = "当前 MySQL 数据不足，暂不能判断峰值时段。"
    if _missing(packet):
        third += "存在缺失或未配置范围，相关变化不作判断。"
    if any(c["inventory_changed"] for c in packet["clusters"]):
        third += "节点清单有变化，请核对可比范围。"
    lines.append(third)
    return "\n".join(f"{i}. {line}" for i, line in enumerate(lines, 1))


def _xml(packet, summary):
    legends = _legend(packet)
    refs = packet["refs"]
    out = [f"<title>{escape(_title(packet))}</title>", "<h1>结论</h1>"]
    out += [f"<p>{escape(line)}</p>" for line in summary.splitlines()]
    out += [f"<p>北京时间：{escape(_window(packet))}；结束时刻不计入本窗。</p>",
            "<h1>指标对照</h1>", "<table><colgroup>"]
    out += [f'<col width="{width}"/>' for width in _COL_WIDTHS]
    out += ["</colgroup><thead><tr>"]
    headers = ("集群", "指标", legends[0], legends[1], legends[2], "变化")
    out += [f"<th>{escape(text)}</th>" for text in headers]
    out += ["</tr></thead><tbody>"]
    for key in _KEYS:
        cluster = _cluster(packet, key)
        for field, metric in (("count", "次数（次）"), ("duration_seconds", "耗时（秒）")):
            unavailable = key == "postgres" and field == "duration_seconds"
            values = [_value(cluster, refs[ref], field) for ref, _, _ in _STYLES]
            if unavailable:
                displays, comparison = ["待核"] * 3, "业务范围未核实"
            elif cluster is None:
                displays, comparison = ["未配置"] * 3, "无可比数据"
            else:
                displays = [_fmt(value, field) for value in values]
                comparison = f"较{legends[1]}{_change(values[0], values[1])}；较{legends[2]}{_change(values[0], values[2])}"
            label = LABELS[key] + ("（全量含后台）" if key == "postgres" and field == "count" else "")
            cells = (label, metric, *displays, comparison)
            out.append("<tr>" + "".join(f"<td>{escape(text)}</td>" for text in cells) + "</tr>")
    out += ["</tbody></table>", "<h1>完整性与口径</h1>"]
    for key in _KEYS:
        cluster = _cluster(packet, key)
        if cluster is None:
            continue
        complete = sum(r["status"] == "complete" for r in cluster["periods"].values())
        out.append(f"<p>{escape(LABELS[key])}：{complete}/{len(cluster['periods'])} 个窗口完成独立小时核验；当前节点 {cluster['node_count']} 个。</p>")
        reasons = Counter(_FAILURE_LABELS.get(r["category"], "数据未完成")
                          for r in cluster["periods"].values() if r["status"] == "failed")
        if reasons:
            out.append("<p>缺失说明：" + "；".join(f"{reason}（{count} 个窗口）" for reason, count in sorted(reasons.items())) + "。</p>")
    out += [f"<p>{escape(line)}</p>" for line in _scope(packet)]
    out += ["<h1>图表</h1>", "<p>下附次数与累计耗时图；实线为目标窗，虚线为前一日同窗，点划线为上周同窗。缺数处不画零。</p>"]
    return "\n".join(out) + "\n"


def _figure(packet, field):
    # Import the raster backend only when rendering; importing this module is inert.
    from matplotlib.backends.backend_agg import FigureCanvasAgg
    from matplotlib.figure import Figure
    from matplotlib import font_manager
    from matplotlib.ticker import FuncFormatter, MaxNLocator

    available = {font.name: font for font in font_manager.fontManager.ttflist}
    family = next((name for name in ("Noto Sans CJK SC", "WenQuanYi Zen Hei", "Source Han Sans SC", "SimHei", "Microsoft YaHei", "Unifont") if name in available), None)
    if family is None:
        raise ReportError("RenderFailure")
    font = font_manager.FontProperties(family=family, weight=available[family].weight)
    legend_font = font.copy()
    legend_font.set_size(13)
    figure = Figure(figsize=(16, 15), dpi=120, facecolor="#fbfcfe")
    FigureCanvasAgg(figure)
    grid = figure.add_gridspec(4, 3, height_ratios=(1, 1, 1, 1.15), hspace=.73, wspace=.36,
                              top=.88, bottom=.105, left=.075, right=.97)
    metric = "慢日志次数" if field == "count" else "慢日志累计耗时"
    unit = "次" if field == "count" else "秒"
    figure.suptitle(_title(packet) + "｜" + metric, fontproperties=font, fontsize=24, y=.976, color="#15263c")
    figure.text(.075, .939, "北京时间：" + _window(packet), fontproperties=font, fontsize=15, color="#4b596d")
    legends = _legend(packet)
    xvalues = list(range(packet["window_hours"]))
    refs = packet["refs"]

    def format_axes(axis):
        axis.set_facecolor("white")
        axis.grid(axis="y", color="#dce3ed", linewidth=.7, alpha=.85)
        axis.spines[["top", "right"]].set_visible(False)
        axis.spines[["left", "bottom"]].set_color("#c7d0dc")
        axis.yaxis.set_major_locator(MaxNLocator(nbins=4, integer=field == "count"))
        axis.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:,.0f}" if field == "count" or abs(value) >= 100 else f"{value:.6f}".rstrip("0").rstrip(".")))
        for label in axis.get_xticklabels() + axis.get_yticklabels():
            label.set_fontproperties(font)
            label.set_fontsize(12)

    for index, key in enumerate(_KEYS):
        cluster = _cluster(packet, key)
        axis = figure.add_subplot(grid[index, :])
        format_axes(axis)
        label = LABELS[key] + ("（全量含后台）" if key == "postgres" and field == "count" else "")
        axis.set_title(label + "｜分小时对照", fontproperties=font, fontsize=17, loc="left", pad=10)
        axis.set_ylabel(unit, fontproperties=font, fontsize=13)
        pg_duration = key == "postgres" and field == "duration_seconds"
        missing_labels = []
        if pg_duration or cluster is None:
            message = "业务耗时待核；业务与后台未分离" if pg_duration else "未配置，未作统计"
            axis.text(.5, .48, message, transform=axis.transAxes, ha="center", va="center", fontproperties=font, fontsize=17, color="#7b6040")
            axis.set_yticks([])
            axis.set_ylabel("")
        else:
            for (ref, color, style), legend in zip(_STYLES, legends):
                result = _result(cluster, refs[ref])
                if result is None:
                    missing_labels.append(legend)
                    continue
                axis.plot(xvalues, [p[field] for p in result["hourly"]], color=color, linestyle=style,
                          linewidth=2.5 if ref == "current" else 1.8, label=legend, zorder=3 if ref == "current" else 2)
            if axis.lines:
                axis.legend(prop=legend_font, loc="lower right", bbox_to_anchor=(1, 1.01),
                            ncol=3, frameon=False, borderaxespad=0)
            if missing_labels:
                axis.text(.01, .91, "缺失：" + "、".join(missing_labels), transform=axis.transAxes,
                          fontproperties=font, fontsize=12, color="#a15b17", va="top")
        axis.set_xlim(-.3, packet["window_hours"] - .7)
        axis.set_ylim(bottom=0)
        if field == "count" and axis.get_ylim()[1] < 1:
            axis.set_ylim(top=1)
        step = 3 if packet["window_hours"] == 24 else 2
        ticks = list(range(0, packet["window_hours"], step))
        if ticks[-1] != packet["window_hours"] - 1:
            ticks.append(packet["window_hours"] - 1)
        axis.set_xticks(ticks, [str(value) for value in ticks])
        axis.set_xlabel("距窗口起点的小时数", fontproperties=font, fontsize=12, labelpad=2)
        for tick in axis.get_xticklabels():
            tick.set_fontproperties(font)

        trend = figure.add_subplot(grid[3, index])
        format_axes(trend)
        trend.set_title(label + ("｜七日趋势" if packet["mode"] == "daily" else "｜七期同窗趋势"), fontproperties=font, fontsize=14, loc="left", pad=10)
        trend.set_ylabel(unit, fontproperties=font, fontsize=12)
        recent = refs["recent"]
        if pg_duration or cluster is None:
            trend.text(.5, .5, "业务耗时待核" if pg_duration else "未配置", transform=trend.transAxes,
                       ha="center", va="center", fontproperties=font, fontsize=15, color="#7b6040")
            trend.set_yticks([])
            trend.set_ylabel("")
        else:
            for i, period_key in enumerate(recent):
                value = _value(cluster, period_key, field)
                if value is None:
                    trend.text(i, .035, "缺失", transform=trend.get_xaxis_transform(), ha="center",
                               fontproperties=font, fontsize=10, color="#a15b17", rotation=90)
                else:
                    trend.bar(i, value, width=.65, color="#1769b5" if i == 6 else "#a7c4df", zorder=3)
                    if value == 0:
                        trend.text(i, .035, "0", transform=trend.get_xaxis_transform(), ha="center",
                                   fontproperties=font, fontsize=11, color="#4b596d")
        trend.set_xlim(-.6, 6.6)
        trend.set_ylim(bottom=0)
        if field == "count" and trend.get_ylim()[1] < 1:
            trend.set_ylim(top=1)
        trend.set_xticks(range(7), [_date(int(p)).strftime("%m-%d") for p in recent], rotation=35, ha="right")
        for tick in trend.get_xticklabels():
            tick.set_fontproperties(font)
            tick.set_fontsize(11)
    figure.text(.075, .056, "缺线、缺柱表示缺数；零只来自已核验的真实零值。各集群独立展示。", fontproperties=font, fontsize=13, color="#4b596d")
    figure.text(.075, .03, "次数含全部账号慢日志；PostgreSQL 全量含后台，业务耗时待核。", fontproperties=font, fontsize=13, color="#4b596d")
    return figure


def _write_png(packet, field, path):
    figure = _figure(packet, field)
    try:
        figure.savefig(path, format="png", dpi=120, facecolor=figure.get_facecolor(),
                       metadata={"Software": ""})
    finally:
        figure.clear()


def _write_csv(packet, directory):
    with (directory / "daily.csv").open("w", newline="", encoding="utf-8-sig") as daily_stream, \
         (directory / "hour.csv").open("w", newline="", encoding="utf-8-sig") as hour_stream:
        daily, hourly = csv.writer(daily_stream), csv.writer(hour_stream)
        daily.writerow(("集群", "窗口起点", "窗口终点", "状态", "慢日志次数", "累计耗时（秒）", "小时核验"))
        hourly.writerow(("集群", "小时起点", "慢日志次数", "累计耗时（秒）"))
        for key in _KEYS:
            cluster = _cluster(packet, key)
            if cluster is None:
                continue
            for period in packet["periods"]:
                result = cluster["periods"][period["key"]]
                complete = result["status"] == "complete"
                duration = "待核" if key == "postgres" else (result["duration_seconds"] if complete else "")
                daily.writerow((LABELS[key], _date(period["start_ms"]).isoformat(), _date(period["end_ms"]).isoformat(),
                                "完成" if complete else "缺失", result["count"] if complete else "", duration,
                                "通过" if complete else "未完成"))
                if complete:
                    for point in result["hourly"]:
                        hourly.writerow((LABELS[key], _date(point["ts"]).isoformat(), point["count"],
                                         "待核" if key == "postgres" else point["duration_seconds"]))


def render_report(packet, directory: Path):
    """Write two PNGs, document XML, three conclusions and safe aggregate CSVs."""
    _validate_packet(packet)
    try:
        directory = Path(directory)
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        summary = _summary(packet)
        (directory / "summary.txt").write_text(summary + "\n", encoding="utf-8")
        (directory / "report.xml").write_text(_xml(packet, summary), encoding="utf-8")
        _write_csv(packet, directory)
        _write_png(packet, "count", directory / "counts.png")
        _write_png(packet, "duration_seconds", directory / "durations.png")
        return {"summary": summary, "xml_name": "report.xml", "images": ["counts.png", "durations.png"]}
    except ReportError:
        raise
    except Exception:
        raise ReportError("RenderFailure") from None
