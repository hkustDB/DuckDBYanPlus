#!/usr/bin/env python3
"""Create the semi-join comparison and cache-boundary runtime-gap figures."""

from __future__ import annotations

import argparse
import csv
import math
import os
import tempfile
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


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
from matplotlib.axes import Axes
from matplotlib.ticker import FuncFormatter


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_COMPARISON_INPUT = (
    Path.home() / "Desktop" / "TODS revision" / "semijoin_comparison_results.csv"
)
DEFAULT_CACHE_INPUT = (
    Path.home() / "Desktop" / "TODS revision" / "semijoin_cache_results.csv"
)
DEFAULT_OUTPUT_DIR = REPOSITORY_ROOT / "figures" / "duckdb_v1_5"
STANDALONE_FIGURE_SIZE = (7.4, 4.7)

BLOOM_COLOR = "#4477AA"
HASH_COLOR = "#CC6677"
GAP_COLOR = "#999999"
BACKEND_STYLE = {
    "Bloom": {
        "label": "Bloom Filter",
        "color": BLOOM_COLOR,
        "hatch": "//",
        "marker": "o",
        "linestyle": "-",
    },
    "Hash": {
        "label": "Hash Filter",
        "color": HASH_COLOR,
        "hatch": "\\\\",
        "marker": "s",
        "linestyle": "--",
    },
}
BOUNDARY_ORDER = (
    "L1d_below",
    "L1d_above",
    "L2_below",
    "L2_above",
    "L3_below",
    "L3_above",
)
BOUNDARY_LINE_LABELS = (
    "L1-L2 boundary\n48-KiB L1",
    "L2-L3 boundary\n1.25-MiB L2",
    "L3-memory boundary\n39-MiB L3",
)
COMPARISON_CAPTION = "(a) Semi-join comparison of LSQB-Q5 variant."
CACHE_CAPTION = "(b) Hash Filter vs Bloom Filter relative to the Cache boundary."

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 10.5,
        "axes.labelsize": 11.5,
        "axes.titlesize": 12,
        "legend.fontsize": 10,
        "xtick.labelsize": 9.5,
        "ytick.labelsize": 9.5,
        "hatch.linewidth": 0.55,
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
    }
)


def finite_number(
    row: Mapping[str, str], column: str, path: Path, *, positive: bool = True
) -> float:
    try:
        value = float(row[column])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError(f"invalid {column!r} value in {path}") from error
    if not math.isfinite(value) or (positive and value <= 0):
        qualifier = "positive and finite" if positive else "finite"
        raise ValueError(f"{column!r} must be {qualifier} in {path}")
    return value


def read_csv(path: Path) -> Tuple[List[Dict[str, str]], Sequence[str]]:
    if not path.is_file():
        raise FileNotFoundError(f"missing input file: {path}")
    with path.open(newline="", encoding="utf-8-sig") as source:
        reader = csv.DictReader(source)
        rows = list(reader)
        columns = tuple(reader.fieldnames or ())
    if not rows:
        raise ValueError(f"input file has no data rows: {path}")
    return rows, columns


def require_columns(columns: Iterable[str], required: Iterable[str], path: Path) -> None:
    missing = set(required) - set(columns)
    if missing:
        raise ValueError(f"{path} is missing columns: {', '.join(sorted(missing))}")


def read_comparison(path: Path) -> List[Dict[str, float]]:
    rows, columns = read_csv(path)
    require_columns(
        columns,
        (
            "query",
            "expected_selectivity_pct",
            "bloom_median_seconds",
            "hash_median_seconds",
        ),
        path,
    )
    selected = [
        row
        for row in rows
        if row.get("query", "").lower() == "lsqb_q5"
        or row.get("query", "").lower().startswith("q5_")
    ]
    if not selected:
        raise ValueError(f"input file has no Q5 comparison rows: {path}")

    parsed: List[Dict[str, float]] = []
    for row in selected:
        query = row["query"]
        selectivity = finite_number(row, "expected_selectivity_pct", path)
        parsed.append(
            {
                "query": query,
                "selectivity": selectivity,
                "bloom": finite_number(row, "bloom_median_seconds", path),
                "hash": finite_number(row, "hash_median_seconds", path),
            }
        )
    parsed.sort(key=lambda row: (-row["selectivity"], str(row["query"])))
    return parsed


def read_cache_probe_times(path: Path) -> Dict[str, List[float]]:
    rows, columns = read_csv(path)
    require_columns(columns, ("backend", "point_labels", "probe_ns_per_key"), path)
    indexed: Dict[Tuple[str, str], float] = {}
    for row in rows:
        backend = row.get("backend", "").strip().lower()
        label = row.get("point_labels", "").strip()
        if backend not in ("bloom", "hash"):
            raise ValueError(f"unknown backend {backend!r} in {path}")
        if label not in BOUNDARY_ORDER:
            raise ValueError(f"unknown cache-boundary label {label!r} in {path}")
        key = (backend, label)
        if key in indexed:
            raise ValueError(f"duplicate cache measurement for {backend}/{label} in {path}")
        indexed[key] = finite_number(row, "probe_ns_per_key", path)

    missing = [
        f"{backend}/{label}"
        for backend in ("bloom", "hash")
        for label in BOUNDARY_ORDER
        if (backend, label) not in indexed
    ]
    if missing:
        raise ValueError(f"missing cache measurements in {path}: {', '.join(missing)}")
    return {
        backend: [indexed[(backend, label)] for label in BOUNDARY_ORDER]
        for backend in ("bloom", "hash")
    }


def style_axis(axis: Axes) -> None:
    axis.grid(True, axis="y", linestyle="--", linewidth=0.55, color="#B8B8B8")
    axis.set_axisbelow(True)
    axis.spines["top"].set_visible(False)
    axis.spines["right"].set_visible(False)


def draw_comparison(axis: Axes, rows: Sequence[Mapping[str, float]]) -> None:
    centers = list(range(len(rows)))
    bar_width = 0.28
    for backend_index, backend in enumerate(("Bloom", "Hash")):
        key = backend.lower()
        positions = [
            center + (-0.5 + backend_index) * bar_width for center in centers
        ]
        style = BACKEND_STYLE[backend]
        axis.bar(
            positions,
            [float(row[key]) for row in rows],
            width=bar_width,
            label=style["label"],
            color=style["color"],
            edgecolor="#505050",
            linewidth=0.35,
            hatch=style["hatch"],
            zorder=3,
        )

    axis.set_yscale("log")
    axis.set_ylim(0.1, 100)
    axis.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:g}"))
    axis.set_ylabel("Query running time (s)")
    axis.set_xticks(centers)
    axis.set_xticklabels(
        [f"Q5{chr(ord('a') + index)}" for index in range(len(rows))]
    )
    axis.legend(loc="upper center", ncol=2, frameon=False, bbox_to_anchor=(0.5, 1.02))
    axis.margins(x=0.045)
    style_axis(axis)


def draw_cache_gap(
    axis: Axes,
    probe_times: Mapping[str, Sequence[float]],
    *,
    visual_scale: float = 1.0,
    legend_y: float = 1.075,
) -> None:
    x_values = list(range(len(BOUNDARY_ORDER)))
    bloom = list(probe_times["bloom"])
    hash_values = list(probe_times["hash"])

    for position, boundary_label in zip(
        (0.5, 2.5, 4.5), BOUNDARY_LINE_LABELS
    ):
        axis.axvline(
            position,
            color="#777777",
            linestyle=":",
            linewidth=1.1 * visual_scale,
            zorder=2,
        )

    axis.fill_between(
        x_values,
        bloom,
        hash_values,
        color=GAP_COLOR,
        alpha=0.18,
        zorder=1,
    )
    for backend, values in (("Bloom", bloom), ("Hash", hash_values)):
        style = BACKEND_STYLE[backend]
        axis.plot(
            x_values,
            values,
            color=style["color"],
            marker=style["marker"],
            linestyle=style["linestyle"],
            linewidth=2.0 * visual_scale,
            markersize=6.0 * visual_scale,
            markeredgecolor="#4A4A4A",
            markeredgewidth=0.45 * visual_scale,
            label=style["label"],
            zorder=3,
        )

    for x_value, bloom_value, hash_value in zip(x_values, bloom, hash_values):
        gap = hash_value - bloom_value
        midpoint = bloom_value + gap / 2
        axis.annotate(
            f"Δ {gap:.1f}",
            (x_value, midpoint),
            ha="center",
            va="center",
            fontsize=8.2 * visual_scale,
            color="#3F3F3F",
            bbox={
                "boxstyle": "round,pad=0.15",
                "facecolor": "white",
                "edgecolor": "none",
                "alpha": 0.82,
            },
            zorder=4,
        )

    upper = max(hash_values)
    axis.set_ylim(0, math.ceil((upper * 1.12) / 5) * 5)
    axis.set_xlim(-0.5, len(x_values) - 0.5)
    axis.set_ylabel("Probe time (ns/key)", fontsize=11.5 * visual_scale)
    axis.set_xticks((0.5, 2.5, 4.5))
    axis.set_xticklabels(
        BOUNDARY_LINE_LABELS,
        rotation=0,
        ha="center",
        fontsize=8.4 * visual_scale,
    )
    axis.tick_params(axis="x", which="both", length=0, pad=2 * visual_scale)
    axis.tick_params(axis="y", labelsize=9.5 * visual_scale)
    axis.legend(
        loc="upper center",
        ncol=2,
        frameon=False,
        bbox_to_anchor=(0.5, legend_y),
        handlelength=2.3,
        fontsize=10 * visual_scale,
    )
    style_axis(axis)


def save_figure(
    figure: plt.Figure,
    stem: Path,
    formats: Sequence[str],
    dpi: int,
    *,
    tight: bool = True,
) -> List[Path]:
    stem.parent.mkdir(parents=True, exist_ok=True)
    destinations: List[Path] = []
    for extension in formats:
        destination = stem.with_suffix(f".{extension}")
        figure.savefig(
            destination,
            dpi=dpi,
            bbox_inches="tight" if tight else None,
            facecolor="white",
        )
        destinations.append(destination)
    return destinations


def plot(
    comparison_path: Path,
    cache_path: Path,
    output_dir: Path,
    formats: Sequence[str],
    dpi: int,
) -> Tuple[List[Path], List[Path], List[float]]:
    comparison_rows = read_comparison(comparison_path)
    probe_times = read_cache_probe_times(cache_path)

    cache_figure, cache_axis = plt.subplots(figsize=STANDALONE_FIGURE_SIZE)
    draw_cache_gap(cache_axis, probe_times, visual_scale=1.22, legend_y=1.10)
    cache_figure.subplots_adjust(bottom=0.18, left=0.14, right=0.98, top=0.90)
    cache_destinations = save_figure(
        cache_figure,
        output_dir / "semijoin_cache_runtime_gap",
        formats,
        dpi,
        tight=False,
    )
    plt.close(cache_figure)

    combined_figure, (comparison_axis, cache_axis) = plt.subplots(
        1,
        2,
        figsize=(14.8, 5.2),
        gridspec_kw={"width_ratios": (1, 1)},
    )
    draw_comparison(comparison_axis, comparison_rows)
    draw_cache_gap(cache_axis, probe_times)
    comparison_axis.text(
        0.5,
        -0.25,
        COMPARISON_CAPTION,
        transform=comparison_axis.transAxes,
        ha="center",
        va="top",
        fontsize=11.5,
    )
    cache_axis.text(
        0.5,
        -0.25,
        CACHE_CAPTION,
        transform=cache_axis.transAxes,
        ha="center",
        va="top",
        fontsize=11.5,
    )
    combined_figure.subplots_adjust(
        bottom=0.24, left=0.065, right=0.995, top=0.88, wspace=0.26
    )
    combined_destinations = save_figure(
        combined_figure, output_dir / "semijoin_combined", formats, dpi
    )
    plt.close(combined_figure)

    gaps = [
        hash_value - bloom_value
        for bloom_value, hash_value in zip(
            probe_times["bloom"], probe_times["hash"]
        )
    ]
    return cache_destinations, combined_destinations, gaps


def parse_args(argv: Optional[Sequence[str]] = None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--comparison-input",
        type=Path,
        default=DEFAULT_COMPARISON_INPUT,
        help="Q5 Bloom Filter/Hash Filter comparison CSV",
    )
    parser.add_argument(
        "--cache-input",
        type=Path,
        default=DEFAULT_CACHE_INPUT,
        help="cache-boundary measurement CSV",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"figure destination (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--formats",
        nargs="+",
        choices=("png", "pdf", "svg"),
        default=("pdf",),
        help="output formats",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=1200,
        help="rasterization resolution for saved figures (default: 1200 dpi)",
    )
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    cache_outputs, combined_outputs, gaps = plot(
        args.comparison_input.expanduser().resolve(),
        args.cache_input.expanduser().resolve(),
        args.output_dir.expanduser().resolve(),
        tuple(dict.fromkeys(args.formats)),
        args.dpi,
    )
    print(
        "Cache gap (Hash Filter - Bloom Filter, ns/key): "
        + ", ".join(f"{gap:.3f}" for gap in gaps)
    )
    print("Cache figure -> " + ", ".join(str(path) for path in cache_outputs))
    print("Combined figure -> " + ", ".join(str(path) for path in combined_outputs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
