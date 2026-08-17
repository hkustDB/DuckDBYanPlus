#!/usr/bin/env python3
"""Plot the DuckDB 1.5 native, Yan, and Yan+ benchmark results.

The four plotted systems are:

* DuckDB1.5: native execution.
* DuckDB1.5-Yan (rewrite): the fastest Yannakakis rewrite variant.
* DuckDB1.5-Yan+ (rewrite): the fastest Yannakakis+ SQL rewrite variant.
* DuckDB1.5-Yan+: the modified-kernel implementation.

Graph's statistics CSV names related measurements q1a/q1b/q1c, q2a/q2b,
and so on, whereas the two new timing CSVs use q1, q2, ... .  The Graph
statistics are therefore grouped by numeric query and the fastest positive
measurement in each group is used.  JOB's Yannakakis+ statistics are stored as
speedups; their runtimes are reconstructed as native_runtime / speedup.
"""

from __future__ import annotations

import argparse
import csv
import math
import os
import re
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


if "MPLCONFIGDIR" not in os.environ:
    _matplotlib_cache = Path(tempfile.gettempdir()) / "duckdb-v15-matplotlib"
    _matplotlib_cache.mkdir(parents=True, exist_ok=True)
    os.environ["MPLCONFIGDIR"] = str(_matplotlib_cache)
if "XDG_CACHE_HOME" not in os.environ:
    _font_cache = Path(tempfile.gettempdir()) / "duckdb-v15-cache"
    _font_cache.mkdir(parents=True, exist_ok=True)
    os.environ["XDG_CACHE_HOME"] = str(_font_cache)

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from matplotlib.ticker import FuncFormatter


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_ROOT = Path.home() / "Desktop" / "TODS revision"
DEFAULT_OUTPUT_DIR = REPOSITORY_ROOT / "figures" / "duckdb_v1_5"

KERNEL_DIR = "DuckdbYanPlus_v1.5"
REWRITE_DIR = "Rewrite_duckdb_1.5"

DUCKDB = "DuckDB1.5"
YAN_REWRITE = "DuckDB1.5-Yan (rewrite)"
YANPLUS_REWRITE = r"DuckDB1.5-Yan$^{+}$ (rewrite)"
YANPLUS = r"DuckDB1.5-Yan$^{+}$"
SERIES_ORDER = (DUCKDB, YAN_REWRITE, YANPLUS_REWRITE, YANPLUS)
SERIES_STYLE = {
    DUCKDB: {"color": "#1f77b4", "hatch": "-"},
    YAN_REWRITE: {"color": "#ff7f0e", "hatch": "*"},
    YANPLUS_REWRITE: {"color": "#30cf4d", "hatch": "\\"},
    YANPLUS: {"color": "#FFB6C1", "hatch": "||"},
}
BAR_EDGE_COLOR = "#505050"
BAR_LINEWIDTH = 0.3
TIME_LIMIT_SECONDS = 7200.0
AXIS_LABEL_SIZE = 16
TICK_LABEL_SIZE = 12
SUBGRAPH_TITLE_SIZE = 15
LEGEND_SIZE = 14


@dataclass(frozen=True)
class FigureData:
    slug: str
    title: str
    query_ids: Sequence[str]
    query_labels: Sequence[str]
    series: Mapping[str, Sequence[Optional[float]]]
    notes: Sequence[str]


def read_csv(path: Path) -> List[Dict[str, str]]:
    if not path.is_file():
        raise FileNotFoundError(f"missing input file: {path}")
    with path.open(newline="", encoding="utf-8-sig") as source:
        rows = list(csv.DictReader(source))
    if not rows:
        raise ValueError(f"input file has no data rows: {path}")
    return rows


def positive_number(value: Optional[str], *, path: Path, query: str) -> Optional[float]:
    if value is None or not value.strip():
        return None
    try:
        number = float(value)
    except ValueError as error:
        raise ValueError(f"invalid value for {query!r} in {path}: {value!r}") from error
    if not math.isfinite(number) or number <= 0:
        return None
    return number


def natural_key(value: str) -> Tuple[object, ...]:
    return tuple(
        int(part) if part.isdigit() else part.lower()
        for part in re.split(r"(\d+)", value)
        if part
    )


def require_match(pattern: str, value: str, path: Path) -> str:
    match = re.fullmatch(pattern, value.strip(), flags=re.IGNORECASE)
    if not match:
        raise ValueError(f"unrecognized query name {value!r} in {path}")
    return match.group(1).lower()


def standard_query(value: str, _path: Path) -> str:
    normalized = value.strip().lower()
    if re.fullmatch(r"q\d+", normalized):
        return normalized[1:]
    return normalized


def rewrite_query(value: str, path: Path) -> str:
    base = require_match(r"(.+?)_rewriteya\d+_yannakakis", value, path)
    return standard_query(base, path)


def graph_kernel_query(value: str, path: Path) -> str:
    return require_match(r"(q\d+)_\d+_rewriter", value, path)


def graph_yan_query(value: str, path: Path) -> str:
    return require_match(r"(q\d+)_rewriteya\d+_yannakakis", value, path)


def graph_statistics_query(value: str, path: Path) -> str:
    number = require_match(r"q(\d+).*", value, path)
    return f"q{int(number)}"


def dsb_current_query(value: str, path: Path) -> str:
    number = require_match(r"(?:query|q)?0*(\d+)", value, path)
    return f"q{int(number)}"


def dsb_rewrite_query(value: str, path: Path) -> str:
    number = require_match(r"q?0*(\d+)_r_rewriter", value, path)
    return f"q{int(number)}"


def update_fastest(result: Dict[str, Optional[float]], query: str, value: Optional[float]):
    if query not in result:
        result[query] = value
    elif value is not None and (result[query] is None or value < result[query]):
        result[query] = value


def grouped_column(
    path: Path,
    query_column: str,
    value_column: str,
    normalizer: Callable[[str, Path], str],
) -> Dict[str, Optional[float]]:
    result: Dict[str, Optional[float]] = {}
    for row in read_csv(path):
        raw_query = row[query_column]
        query = normalizer(raw_query, path)
        value = positive_number(row.get(value_column), path=path, query=raw_query)
        update_fastest(result, query, value)
    return result


def current_native_and_kernel(
    path: Path, normalizer: Callable[[str, Path], str]
) -> Tuple[Dict[str, Optional[float]], Dict[str, Optional[float]]]:
    native: Dict[str, Optional[float]] = {}
    kernel: Dict[str, Optional[float]] = {}
    for row in read_csv(path):
        query = normalizer(row["Query"], path)
        native[query] = positive_number(row.get("origin"), path=path, query=row["Query"])
        kernel[query] = positive_number(row.get("yanplus"), path=path, query=row["Query"])
    return native, kernel


def common_query_ids(suite: str, sources: Sequence[Mapping[str, object]]):
    query_ids = set(sources[0])
    for source in sources[1:]:
        query_ids &= set(source)
    if not query_ids:
        raise ValueError(f"{suite}: no common query names across the required sources")

    common = sorted(query_ids, key=natural_key)
    notes = []
    union = set().union(*(set(source) for source in sources))
    omitted = sorted(union - query_ids, key=natural_key)
    if omitted:
        notes.append(f"queries without all required sources omitted: {', '.join(omitted)}")
    return common, notes


def display_query(query: str) -> str:
    return query.upper() if query.startswith("q") else f"Q{query.upper()}"


def load_standard_suite(data_root: Path, slug: str, title: str) -> FigureData:
    current_filename = {
        "lsqb": "timing_summary_lsqb.csv",
        "tpch": "timing_summary_tpch.csv",
        "job": "timing_summary_job_agg.csv",
    }[slug]
    yan_filename = f"timing_summary_yannakakis_rewrite_{slug}.csv"
    statistics_filename = f"summary_{slug}_statistics.csv"

    current_path = data_root / KERNEL_DIR / current_filename
    yan_path = data_root / REWRITE_DIR / yan_filename
    statistics_path = data_root / REWRITE_DIR / statistics_filename

    native, kernel = current_native_and_kernel(current_path, standard_query)
    yan_rewrite = grouped_column(
        yan_path, "Query", "Average_Time", rewrite_query
    )

    if slug == "job":
        speedups = grouped_column(
            statistics_path,
            "JOB",
            "DuckDB Yannakakis+ speedup",
            standard_query,
        )
        yanplus_rewrite = {
            query: (
                native[query] / speedup
                if native.get(query) is not None and speedup is not None
                else None
            )
            for query, speedup in speedups.items()
        }
        conversion_note = (
            "DuckDB1.5-Yan+ rewrite runtimes are DuckDB1.5 runtime divided by "
            "the reported Yannakakis+ speedup."
        )
    else:
        yanplus_rewrite = grouped_column(
            statistics_path, "Query", "DuckDB rewrite", standard_query
        )
        conversion_note = None

    query_ids, notes = common_query_ids(
        slug, (native, kernel, yan_rewrite, yanplus_rewrite)
    )
    if conversion_note:
        notes.append(conversion_note)

    return FigureData(
        slug=slug,
        title=title,
        query_ids=query_ids,
        query_labels=[display_query(query) for query in query_ids],
        series={
            DUCKDB: [native.get(query) for query in query_ids],
            YAN_REWRITE: [yan_rewrite.get(query) for query in query_ids],
            YANPLUS_REWRITE: [yanplus_rewrite.get(query) for query in query_ids],
            YANPLUS: [kernel.get(query) for query in query_ids],
        },
        notes=notes,
    )


def load_graph(data_root: Path) -> FigureData:
    kernel_path = data_root / KERNEL_DIR / "timing_summary_graph.csv"
    yan_path = data_root / REWRITE_DIR / "timing_summary_yannakakis_rewrite_graph.csv"
    statistics_path = data_root / REWRITE_DIR / "summary_graph_statistics.csv"

    kernel = grouped_column(
        kernel_path, "Query", "Average_Time", graph_kernel_query
    )
    yan_rewrite = grouped_column(
        yan_path, "Query", "Average_Time", graph_yan_query
    )
    native = grouped_column(
        statistics_path, "Query", "DuckDB native", graph_statistics_query
    )
    yanplus_rewrite = grouped_column(
        statistics_path, "Query", "DuckDB rewrite", graph_statistics_query
    )
    query_ids, notes = common_query_ids(
        "graph", (native, yan_rewrite, yanplus_rewrite, kernel)
    )
    notes.append(
        "Graph qNa/qNb/qNc statistics are collapsed to the fastest positive "
        "measurement for numeric query qN."
    )

    return FigureData(
        slug="graph",
        title="Graph",
        query_ids=query_ids,
        query_labels=[query.upper() for query in query_ids],
        series={
            DUCKDB: [native.get(query) for query in query_ids],
            YAN_REWRITE: [yan_rewrite.get(query) for query in query_ids],
            YANPLUS_REWRITE: [yanplus_rewrite.get(query) for query in query_ids],
            YANPLUS: [kernel.get(query) for query in query_ids],
        },
        notes=notes,
    )


def load_dsb_part(data_root: Path, part: str):
    current_path = data_root / KERNEL_DIR / f"timing_summary_dsb_{part}.csv"
    rewrite_path = data_root / REWRITE_DIR / f"timing_summary_dsb_{part}_rewrite.csv"
    native, kernel = current_native_and_kernel(current_path, dsb_current_query)
    yanplus_rewrite = grouped_column(
        rewrite_path, "Query", "Average_Time", dsb_rewrite_query
    )
    query_ids, notes = common_query_ids(
        f"dsb-{part}", (native, kernel, yanplus_rewrite)
    )
    return query_ids, native, kernel, yanplus_rewrite, notes


def load_dsb(data_root: Path) -> FigureData:
    query_ids: List[str] = []
    labels: List[str] = []
    native_values: List[Optional[float]] = []
    yanplus_rewrite_values: List[Optional[float]] = []
    kernel_values: List[Optional[float]] = []
    notes = ["No DuckDB1.5-Yan rewrite timing file is present for DSB."]

    for part, prefix in (("spj", "SPJ"), ("agg", "AGG")):
        part_ids, native, kernel, yanplus_rewrite, part_notes = load_dsb_part(
            data_root, part
        )
        query_ids.extend(f"{prefix.lower()}-{query}" for query in part_ids)
        labels.extend(f"{prefix}-{query.upper()}" for query in part_ids)
        native_values.extend(native.get(query) for query in part_ids)
        yanplus_rewrite_values.extend(yanplus_rewrite.get(query) for query in part_ids)
        kernel_values.extend(kernel.get(query) for query in part_ids)
        notes.extend(f"{prefix}: {note}" for note in part_notes)

    return FigureData(
        slug="dsb",
        title="DSB",
        query_ids=query_ids,
        query_labels=labels,
        series={
            DUCKDB: native_values,
            YANPLUS_REWRITE: yanplus_rewrite_values,
            YANPLUS: kernel_values,
        },
        notes=notes,
    )


def load_all(data_root: Path) -> Dict[str, FigureData]:
    return {
        "graph": load_graph(data_root),
        "lsqb": load_standard_suite(data_root, "lsqb", "LSQB"),
        "tpch": load_standard_suite(data_root, "tpch", "TPC-H"),
        "job": load_standard_suite(data_root, "job", "JOB"),
        "dsb": load_dsb(data_root),
    }


def choose_scale(values: Iterable[float], requested: str) -> str:
    if requested != "auto":
        return requested
    positive = [value for value in values if value > 0]
    if not positive:
        return "linear"
    return "log" if max(positive) / min(positive) >= 50 else "linear"


def format_runtime_axis(axis, active_scale: str, values: Sequence[float]) -> None:
    axis.set_yscale(active_scale)
    if active_scale != "log":
        positive = [value for value in values if value > 0]
        if any(value >= TIME_LIMIT_SECONDS for value in positive):
            axis.set_ylim(0, max(positive))
        else:
            axis.margins(y=0.05)
        return

    axis.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:.1e}"))
    positive = [value for value in values if value > 0]
    if positive:
        lower = 10 ** math.floor(math.log10(min(positive)))
        upper = 10 ** math.ceil(math.log10(max(positive)))
        if min(positive) / lower < 1.05:
            lower /= 10
        if upper / max(positive) < 1.05:
            upper *= 10
        axis.set_ylim(lower, upper)


def timeout_ceiling(active_scale: str, values: Sequence[float]) -> float:
    positive = [value for value in values if value > 0]
    if not positive:
        return TIME_LIMIT_SECONDS
    if active_scale != "log":
        return max(positive)

    upper = 10 ** math.ceil(math.log10(max(positive)))
    if upper / max(positive) < 1.05:
        upper *= 10
    return upper


def display_runtime(value: Optional[float], ceiling: float) -> Optional[float]:
    if value is not None and value >= TIME_LIMIT_SECONDS:
        return ceiling
    return value


def plot_panel(
    axis,
    data: FigureData,
    requested_scale: str,
):
    series_names = [name for name in SERIES_ORDER if name in data.series]
    query_count = len(data.query_labels)
    group_width = 0.88
    bar_width = group_width / len(series_names)
    centers = list(range(query_count))
    all_values = [
        value
        for values in data.series.values()
        for value in values
        if value is not None and value > 0
    ]
    active_scale = choose_scale(all_values, requested_scale)
    ceiling = timeout_ceiling(active_scale, all_values)

    for series_index, series_name in enumerate(series_names):
        offset = -group_width / 2 + bar_width / 2 + series_index * bar_width
        positions = [center + offset for center in centers]
        values = data.series[series_name]
        display_values = [display_runtime(value, ceiling) for value in values]
        present_positions = [
            position
            for position, value in zip(positions, display_values)
            if value is not None
        ]
        present_values = [value for value in display_values if value is not None]
        style = SERIES_STYLE[series_name]
        axis.bar(
            present_positions,
            present_values,
            width=bar_width,
            color=style["color"],
            edgecolor=BAR_EDGE_COLOR,
            linewidth=BAR_LINEWIDTH,
            hatch=style["hatch"],
            zorder=3,
        )
        for position, value in zip(positions, values):
            if value is None:
                axis.annotate(
                    "N/A",
                    xy=(position, 0.01),
                    xycoords=("data", "axes fraction"),
                    rotation=90,
                    ha="center",
                    va="bottom",
                    fontsize=6,
                    color="#555555",
                )

    axis.set_ylabel("Running Time (Sec)", fontsize=AXIS_LABEL_SIZE)
    axis.set_xticks(centers)
    axis.set_xticklabels(
        data.query_labels,
        rotation=0,
        ha="center",
        fontsize=TICK_LABEL_SIZE,
    )
    axis.tick_params(axis="y", labelsize=TICK_LABEL_SIZE)
    format_runtime_axis(axis, active_scale, all_values)
    axis.set_xlim(-0.52, query_count - 0.48)
    axis.grid(True, which="major", linestyle="--", linewidth=0.5, zorder=0)
    axis.set_axisbelow(True)
    return active_scale


def plot_combined_axis(axis, panels: Sequence[FigureData], requested_scale: str):
    all_values = [
        value
        for panel in panels
        for values in panel.series.values()
        for value in values
        if value is not None and value > 0
    ]
    active_scale = choose_scale(all_values, requested_scale)
    ceiling = timeout_ceiling(active_scale, all_values)
    query_labels: List[str] = []
    section_bounds = []
    cursor = 0

    for panel in panels:
        series_names = [name for name in SERIES_ORDER if name in panel.series]
        group_width = 0.88
        bar_width = group_width / len(series_names)
        centers = list(range(cursor, cursor + len(panel.query_ids)))
        section_bounds.append((centers[0], centers[-1], panel.title))
        query_labels.extend(panel.query_labels)

        for series_index, series_name in enumerate(series_names):
            offset = -group_width / 2 + bar_width / 2 + series_index * bar_width
            positions = [center + offset for center in centers]
            values = panel.series[series_name]
            display_values = [display_runtime(value, ceiling) for value in values]
            present_positions = [
                position
                for position, value in zip(positions, display_values)
                if value is not None
            ]
            present_values = [value for value in display_values if value is not None]
            style = SERIES_STYLE[series_name]
            axis.bar(
                present_positions,
                present_values,
                width=bar_width,
                color=style["color"],
                edgecolor=BAR_EDGE_COLOR,
                linewidth=BAR_LINEWIDTH,
                hatch=style["hatch"],
                zorder=3,
            )
            for position, value in zip(positions, values):
                if value is None:
                    axis.annotate(
                        "N/A",
                        xy=(position, 0.01),
                        xycoords=("data", "axes fraction"),
                        rotation=90,
                        ha="center",
                        va="bottom",
                        fontsize=6,
                        color="#555555",
                    )
        cursor += len(panel.query_ids)

    for first, last, title in section_bounds:
        midpoint = (first + last) / 2
        axis.text(
            midpoint,
            -0.105,
            title,
            transform=axis.get_xaxis_transform(),
            ha="center",
            va="top",
            fontsize=SUBGRAPH_TITLE_SIZE,
            clip_on=False,
        )

    centers = list(range(len(query_labels)))
    axis.set_ylabel("Running Time (Sec)", fontsize=AXIS_LABEL_SIZE)
    axis.set_xticks(centers)
    axis.set_xticklabels(
        query_labels,
        rotation=0,
        ha="center",
        fontsize=TICK_LABEL_SIZE,
    )
    axis.tick_params(axis="y", labelsize=TICK_LABEL_SIZE)
    format_runtime_axis(axis, active_scale, all_values)
    axis.set_xlim(-0.52, len(query_labels) - 0.48)
    axis.grid(True, which="major", linestyle="--", linewidth=0.5, zorder=0)
    axis.set_axisbelow(True)
    return active_scale


def legend_handles(series_names: Sequence[str]):
    return [
        Patch(
            facecolor=SERIES_STYLE[name]["color"],
            edgecolor=BAR_EDGE_COLOR,
            linewidth=BAR_LINEWIDTH,
            hatch=SERIES_STYLE[name]["hatch"],
            label=name,
        )
        for name in SERIES_ORDER
        if name in series_names
    ]


def save_figure(figure, output_dir: Path, basename: str, formats: Sequence[str], dpi: int):
    output_dir.mkdir(parents=True, exist_ok=True)
    destinations = []
    for extension in formats:
        destination = output_dir / f"{basename}.{extension}"
        figure.savefig(destination, dpi=dpi, bbox_inches="tight")
        destinations.append(destination)
    plt.close(figure)
    return destinations


def plot_merged(
    panels: Sequence[FigureData],
    basename: str,
    output_dir: Path,
    formats: Sequence[str],
    dpi: int,
    scale: str,
):
    query_count = sum(len(panel.query_ids) for panel in panels)
    width = min(35.0, max(16.0, 2.0 + 0.9 * query_count))
    figure, axis = plt.subplots(figsize=(width, 7.5))
    active_scale = plot_combined_axis(axis, panels, scale)

    present_series = {
        series_name for panel in panels for series_name in panel.series
    }
    axis.legend(
        handles=legend_handles(tuple(present_series)),
        loc="lower center",
        bbox_to_anchor=(0.5, 1.01),
        ncol=min(4, len(present_series)),
        frameon=False,
        fontsize=LEGEND_SIZE,
        borderaxespad=0,
    )
    figure.subplots_adjust(top=0.92, bottom=0.17, left=0.065, right=0.995)
    return save_figure(figure, output_dir, basename, formats, dpi), active_scale


def subset(data: FigureData, first_family: int, last_family: int) -> FigureData:
    indices = []
    for index, query in enumerate(data.query_ids):
        match = re.match(r"(\d+)", query)
        if match and first_family <= int(match.group(1)) <= last_family:
            indices.append(index)
    if not indices:
        raise ValueError(f"JOB partition {first_family}-{last_family} is empty")
    return FigureData(
        slug=f"job_{first_family}_{last_family}",
        title=f"JOB queries {first_family}-{last_family}",
        query_ids=[data.query_ids[index] for index in indices],
        query_labels=[data.query_labels[index] for index in indices],
        series={
            name: [values[index] for index in indices]
            for name, values in data.series.items()
        },
        notes=data.notes,
    )


def plot_job_partitions(
    data: FigureData,
    output_dir: Path,
    formats: Sequence[str],
    dpi: int,
    scale: str,
):
    results = []
    for first_family, last_family in ((1, 7), (8, 14), (15, 20), (21, 27), (28, 33)):
        panel = subset(data, first_family, last_family)
        width = min(35.0, max(14.0, 2.5 + 0.7 * len(panel.query_ids)))
        figure, axis = plt.subplots(figsize=(width, 7.5))
        active_scale = plot_panel(
            axis,
            panel,
            scale,
        )
        axis.legend(
            handles=legend_handles(tuple(panel.series)),
            loc="lower center",
            bbox_to_anchor=(0.5, 1.01),
            ncol=4,
            frameon=False,
            fontsize=LEGEND_SIZE,
            borderaxespad=0,
        )
        figure.subplots_adjust(top=0.92, bottom=0.10, left=0.065, right=0.995)
        basename = f"job_benchmark_{first_family}_{last_family}"
        destinations = save_figure(figure, output_dir, basename, formats, dpi)
        results.append((basename, destinations, active_scale, len(panel.query_ids)))
    return results


def parse_args(argv: Optional[Sequence[str]] = None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=DEFAULT_DATA_ROOT,
        help=f"result root (default: {DEFAULT_DATA_ROOT})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"figure destination (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--benchmarks",
        nargs="+",
        choices=("all", "graph", "lsqb", "tpch", "job", "dsb"),
        default=("all",),
        help="benchmark suites to include",
    )
    parser.add_argument(
        "--formats",
        nargs="+",
        choices=("png", "pdf", "svg"),
        default=("png", "pdf"),
        help="output formats",
    )
    parser.add_argument("--dpi", type=int, default=220, help="PNG resolution")
    parser.add_argument(
        "--scale",
        choices=("auto", "linear", "log"),
        default="log",
        help="y-axis scale (default: log, matching the reference drawing style)",
    )
    return parser.parse_args(argv)


def report_notes(panels: Sequence[FigureData]):
    for panel in panels:
        for note in panel.notes:
            print(f"  {panel.title} note: {note}")


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    data_root = args.data_root.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    formats = tuple(dict.fromkeys(args.formats))
    selected = (
        {"graph", "lsqb", "tpch", "job", "dsb"}
        if "all" in args.benchmarks
        else set(args.benchmarks)
    )
    loaders = {
        "graph": lambda: load_graph(data_root),
        "lsqb": lambda: load_standard_suite(data_root, "lsqb", "LSQB"),
        "tpch": lambda: load_standard_suite(data_root, "tpch", "TPC-H"),
        "job": lambda: load_standard_suite(data_root, "job", "JOB"),
        "dsb": lambda: load_dsb(data_root),
    }
    available = {name: loaders[name]() for name in selected}

    graph_lsqb = [available[name] for name in ("graph", "lsqb") if name in selected]
    if graph_lsqb:
        destinations, active_scale = plot_merged(
            graph_lsqb,
            "graph_lsqb_benchmark",
            output_dir,
            formats,
            args.dpi,
            args.scale,
        )
        print(
            "graph/lsqb: "
            + active_scale
            + " scale -> "
            + ", ".join(str(path) for path in destinations)
        )
        report_notes(graph_lsqb)

    tpch_dsb = [available[name] for name in ("tpch", "dsb") if name in selected]
    if tpch_dsb:
        destinations, active_scale = plot_merged(
            tpch_dsb,
            "tpch_dsb_benchmark",
            output_dir,
            formats,
            args.dpi,
            args.scale,
        )
        print(
            "tpch/dsb: "
            + active_scale
            + " scale -> "
            + ", ".join(str(path) for path in destinations)
        )
        report_notes(tpch_dsb)

    if "job" in selected:
        for basename, destinations, active_scale, count in plot_job_partitions(
            available["job"], output_dir, formats, args.dpi, args.scale
        ):
            print(
                f"{basename}: {count} queries, {active_scale} scale -> "
                + ", ".join(str(path) for path in destinations)
            )
        report_notes((available["job"],))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
