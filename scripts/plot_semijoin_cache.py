#!/usr/bin/env python3
"""Plot Yan+ filter memory and cache-boundary build/probe measurements."""

from __future__ import annotations

import argparse
import csv
import math
import os
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple


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
from matplotlib.lines import Line2D
from matplotlib.ticker import FuncFormatter


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = Path.home() / "Desktop" / "TODS revision" / "semijoin_cache_results.csv"
DEFAULT_OUTPUT_DIR = REPOSITORY_ROOT / "figures" / "duckdb_v1_5"
MIB = 1024 * 1024
BLOOM_MAX_SECTORS = 1 << 26
HASH_RETAINED_BOXED_BYTES = 64 * 16
BACKEND_STYLES = {
    "bloom": {"label": "Bloom", "color": "#1f77b4", "marker": "o"},
    "hash": {"label": "Hash", "color": "#ff7f0e", "marker": "s"},
}
CACHE_STYLES = {
    "L1d": {"color": "#777777", "linestyle": ":"},
    "L2": {"color": "#777777", "linestyle": "--"},
    "L3": {"color": "#444444", "linestyle": "-."},
}
REQUIRED_COLUMNS = {
    "backend",
    "build_keys",
    "filter_bytes",
    "build_ns_per_key",
    "probe_ns_per_key",
    "l1d_bytes",
    "l2_bytes",
    "l3_bytes",
}


def next_power_of_two(value: int) -> int:
    if value <= 1:
        return 1
    return 1 << (value - 1).bit_length()


def bloom_filter_bytes(build_rows: int) -> int:
    minimum_bits = max(512, build_rows * 12)
    sectors = min(next_power_of_two(minimum_bits) >> 6, BLOOM_MAX_SECTORS)
    return 64 + sectors * 8


def hash_filter_bytes(distinct_keys: int) -> int:
    capacity = 64
    while distinct_keys > capacity - (capacity >> 2):
        capacity *= 2
    return HASH_RETAINED_BOXED_BYTES + capacity * 16 + math.ceil(capacity / 64) * 8


MEMORY_FUNCTIONS = {"bloom": bloom_filter_bytes, "hash": hash_filter_bytes}


def positive_number(row: Dict[str, str], column: str, path: Path) -> float:
    try:
        value = float(row[column])
    except (KeyError, ValueError) as error:
        raise ValueError(f"invalid {column!r} in {path}") from error
    if not math.isfinite(value) or value <= 0:
        raise ValueError(f"{column!r} must be positive in {path}")
    return value


def read_rows(path: Path) -> Tuple[List[Dict[str, str]], Dict[str, int]]:
    if not path.is_file():
        raise FileNotFoundError(f"missing input file: {path}")
    with path.open(newline="", encoding="utf-8-sig") as source:
        reader = csv.DictReader(source)
        missing = REQUIRED_COLUMNS - set(reader.fieldnames or ())
        if missing:
            raise ValueError(f"{path} is missing columns: {', '.join(sorted(missing))}")
        rows = list(reader)
    if not rows:
        raise ValueError(f"input file has no cache measurements: {path}")
    unknown = sorted(set(row["backend"].lower() for row in rows) - set(BACKEND_STYLES))
    if unknown:
        raise ValueError(f"unknown backend(s) in {path}: {', '.join(unknown)}")
    cache_sizes: Dict[str, int] = {}
    for cache_name, column in (("L1d", "l1d_bytes"), ("L2", "l2_bytes"), ("L3", "l3_bytes")):
        values = {round(positive_number(row, column, path)) for row in rows}
        if len(values) != 1:
            raise ValueError(f"{column} changes between rows in {path}")
        cache_sizes[cache_name] = values.pop()
    if not cache_sizes["L1d"] < cache_sizes["L2"] < cache_sizes["L3"]:
        raise ValueError(f"cache sizes must satisfy L1d < L2 < L3 in {path}")
    return rows, cache_sizes


def logarithmic_points(minimum: int, maximum: int, count: int = 300) -> List[int]:
    if minimum == maximum:
        return [minimum]
    lower = math.log10(minimum)
    upper = math.log10(maximum)
    return sorted(
        {
            max(1, round(10 ** (lower + index * (upper - lower) / (count - 1))))
            for index in range(count)
        }
    )


def maybe_log_y(axis, values: Sequence[float]) -> None:
    positive = [value for value in values if value > 0]
    if positive and max(positive) / min(positive) >= 20:
        axis.set_yscale("log")
        axis.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:.1e}"))


def add_cache_lines(axis, cache_sizes: Dict[str, int], orientation: str) -> None:
    for cache_name, cache_bytes in cache_sizes.items():
        style = CACHE_STYLES[cache_name]
        cache_mib = cache_bytes / MIB
        if orientation == "horizontal":
            axis.axhline(
                cache_mib,
                color=style["color"],
                linestyle=style["linestyle"],
                linewidth=0.9,
                zorder=1,
            )
        else:
            axis.axvline(
                cache_mib,
                color=style["color"],
                linestyle=style["linestyle"],
                linewidth=0.9,
                zorder=1,
            )


def style_axis(axis) -> None:
    axis.grid(True, which="major", linestyle="--", linewidth=0.5, zorder=0)
    axis.set_axisbelow(True)
    axis.tick_params(axis="both", labelsize=11)


def plot(path: Path, output_dir: Path, formats: Sequence[str], dpi: int):
    rows, cache_sizes = read_rows(path)
    parsed: Dict[str, List[Dict[str, float]]] = {"bloom": [], "hash": []}
    for row in rows:
        backend = row["backend"].lower()
        build_keys = round(positive_number(row, "build_keys", path))
        filter_bytes = round(positive_number(row, "filter_bytes", path))
        expected_bytes = MEMORY_FUNCTIONS[backend](build_keys)
        if filter_bytes != expected_bytes:
            raise ValueError(
                f"{backend}/{build_keys} reports {filter_bytes} filter bytes; "
                f"the implementation model expects {expected_bytes} in {path}"
            )
        parsed[backend].append(
            {
                "build_keys": build_keys,
                "filter_mib": filter_bytes / MIB,
                "build_ns": positive_number(row, "build_ns_per_key", path),
                "probe_ns": positive_number(row, "probe_ns_per_key", path),
            }
        )
    missing_backends = [backend for backend, backend_rows in parsed.items() if not backend_rows]
    if missing_backends:
        raise ValueError(f"input file has no rows for: {', '.join(missing_backends)}")
    for backend_rows in parsed.values():
        backend_rows.sort(key=lambda row: (row["filter_mib"], row["build_keys"]))

    figure, axes = plt.subplots(
        3,
        1,
        figsize=(9.4, 10.8),
        gridspec_kw={"height_ratios": (1.1, 1, 1), "hspace": 0.31},
    )
    memory_axis, build_axis, probe_axis = axes

    for backend, style in BACKEND_STYLES.items():
        sampled_keys = [row["build_keys"] for row in parsed[backend]]
        model_keys = logarithmic_points(
            max(1, int(min(sampled_keys) / 2)), int(max(sampled_keys) * 2)
        )
        memory_axis.plot(
            model_keys,
            [MEMORY_FUNCTIONS[backend](key) / MIB for key in model_keys],
            color=style["color"],
            linewidth=1.8,
            drawstyle="steps-post",
            zorder=2,
        )
        memory_axis.scatter(
            [row["build_keys"] for row in parsed[backend]],
            [row["filter_mib"] for row in parsed[backend]],
            color=style["color"],
            marker=style["marker"],
            s=27,
            zorder=3,
        )
    add_cache_lines(memory_axis, cache_sizes, "horizontal")
    memory_axis.set_xscale("log")
    memory_axis.set_yscale("log")
    memory_axis.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:.1e}"))
    memory_axis.set_ylabel("Allocated filter memory (MiB)", fontsize=14)
    memory_axis.set_xlabel("Unique build keys", fontsize=14)
    style_axis(memory_axis)

    for axis, metric, label in (
        (build_axis, "build_ns", "Build time (ns/key)"),
        (probe_axis, "probe_ns", "Probe time (ns/key)"),
    ):
        values = []
        for backend, style in BACKEND_STYLES.items():
            x_values = [row["filter_mib"] for row in parsed[backend]]
            y_values = [row[metric] for row in parsed[backend]]
            values.extend(y_values)
            axis.plot(
                x_values,
                y_values,
                color=style["color"],
                marker=style["marker"],
                markersize=5,
                linewidth=1.5,
                zorder=3,
            )
        add_cache_lines(axis, cache_sizes, "vertical")
        axis.set_xscale("log")
        maybe_log_y(axis, values)
        axis.set_ylabel(label, fontsize=14)
        style_axis(axis)
    build_axis.tick_params(axis="x", labelbottom=False)
    probe_axis.set_xlabel("Final allocated filter memory (MiB)", fontsize=14)

    legend_handles = [
        Line2D(
            [0],
            [0],
            color=style["color"],
            marker=style["marker"],
            linewidth=1.7,
            label=style["label"],
        )
        for style in BACKEND_STYLES.values()
    ]
    legend_handles.extend(
        Line2D(
            [0],
            [0],
            color=CACHE_STYLES[name]["color"],
            linestyle=CACHE_STYLES[name]["linestyle"],
            linewidth=1,
            label=f"{name} ({cache_sizes[name] / MIB:.4g} MiB)",
        )
        for name in ("L1d", "L2", "L3")
    )
    memory_axis.legend(
        handles=legend_handles,
        loc="lower center",
        bbox_to_anchor=(0.5, 1.01),
        frameon=False,
        ncol=5,
        fontsize=10.5,
        handlelength=2.5,
        columnspacing=1.1,
        borderaxespad=0,
    )
    figure.subplots_adjust(bottom=0.06, top=0.955, left=0.11, right=0.985)

    output_dir.mkdir(parents=True, exist_ok=True)
    destinations = []
    for extension in formats:
        destination = output_dir / f"semijoin_cache_boundary.{extension}"
        figure.savefig(destination, dpi=dpi, bbox_inches="tight")
        destinations.append(destination)
    plt.close(figure)
    return destinations


def parse_args(argv: Optional[Sequence[str]] = None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="cache CSV")
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
        default=("png", "pdf"),
    )
    parser.add_argument("--dpi", type=int, default=220, help="PNG resolution")
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    destinations = plot(
        args.input.expanduser().resolve(),
        args.output_dir.expanduser().resolve(),
        tuple(dict.fromkeys(args.formats)),
        args.dpi,
    )
    print("Cache-boundary figure -> " + ", ".join(str(path) for path in destinations))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
