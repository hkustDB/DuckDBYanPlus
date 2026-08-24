"""Plot Bloom Filter and Hash Filter runtime for the Q5 semi-join variants."""

from __future__ import annotations

import argparse
import csv
import math
import os
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Sequence


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
from matplotlib.ticker import FuncFormatter


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = Path.home() / "Desktop" / "TODS revision" / "semijoin_comparison_results.csv"
DEFAULT_OUTPUT_DIR = REPOSITORY_ROOT / "figures" / "duckdb_v1_5"
STANDALONE_FIGURE_SIZE = (7.4, 4.7)

BACKEND_STYLE = {
    "Bloom": {"label": "Bloom Filter", "color": "#4477AA", "hatch": "//"},
    "Hash": {"label": "Hash Filter", "color": "#CC6677", "hatch": "\\\\"},
}
plt.rcParams["hatch.linewidth"] = 0.6


def read_q5_rows(path: Path) -> List[Dict[str, str]]:
    if not path.is_file():
        raise FileNotFoundError(f"missing input file: {path}")
    with path.open(newline="", encoding="utf-8-sig") as source:
        rows = list(csv.DictReader(source))
    q5_rows = [
        row
        for row in rows
        if row.get("query", "").lower() == "lsqb_q5"
        or row.get("query", "").lower().startswith("q5_")
    ]
    if not q5_rows:
        raise ValueError(f"input file has no Q5 comparison rows: {path}")

    def selectivity(row: Dict[str, str]) -> float:
        if row.get("query", "").lower() == "lsqb_q5":
            return 100.0
        try:
            return float(row.get("expected_selectivity_pct", ""))
        except ValueError as error:
            raise ValueError(
                f"invalid Q5 selectivity for {row.get('query', '<unknown>')!r} in {path}"
            ) from error

    q5_rows.sort(key=lambda row: (-selectivity(row), row.get("query", "")))
    return q5_rows


def positive_number(row: Dict[str, str], column: str, path: Path) -> float:
    try:
        value = float(row[column])
    except (KeyError, ValueError) as error:
        raise ValueError(
            f"invalid {column!r} value for query {row.get('query', '<unknown>')!r} in {path}"
        ) from error
    if not math.isfinite(value) or value <= 0:
        raise ValueError(
            f"{column!r} must be positive for query {row.get('query', '<unknown>')!r} in {path}"
        )
    return value


def plot(path: Path, output_dir: Path, formats: Sequence[str], dpi: int):
    rows = read_q5_rows(path)
    labels = [f"Q5{chr(ord('a') + index)}" for index in range(len(rows))]
    centers = list(range(len(rows)))
    figure, axis = plt.subplots(figsize=STANDALONE_FIGURE_SIZE)
    bar_width = 0.28
    medians = {}

    for backend_index, backend in enumerate(("Bloom", "Hash")):
        prefix = backend.lower()
        backend_medians = [
            positive_number(row, f"{prefix}_median_seconds", path) for row in rows
        ]
        medians[backend] = backend_medians
        positions = [
            center + (-0.5 + backend_index) * bar_width for center in centers
        ]
        style = BACKEND_STYLE[backend]
        axis.bar(
            positions,
            backend_medians,
            width=bar_width,
            label=style["label"],
            color=style["color"],
            edgecolor="#505050",
            linewidth=0.3,
            hatch=style["hatch"],
            zorder=3,
        )

    speedups = [
        hash_time / bloom_time
        for bloom_time, hash_time in zip(medians["Bloom"], medians["Hash"])
    ]

    active_scale = "log"
    axis.set_yscale(active_scale)
    axis.yaxis.set_major_formatter(FuncFormatter(lambda value, _position: f"{value:.1e}"))
    all_medians = medians["Bloom"] + medians["Hash"]
    lower = 10 ** math.floor(math.log10(min(all_medians)))
    upper = 10 ** math.ceil(math.log10(max(all_medians)))
    if min(all_medians) / lower < 1.05:
        lower /= 10
    if upper / max(all_medians) < 1.05:
        upper *= 10
    axis.set_ylim(lower, upper)
    axis.set_ylabel("Running Time (Sec)", fontsize=16)
    axis.set_xticks(centers)
    axis.set_xticklabels(labels, rotation=0, ha="center", fontsize=12)
    axis.tick_params(axis="y", labelsize=12)
    axis.grid(
        True,
        which="major",
        linestyle="--",
        linewidth=0.5,
        zorder=0,
    )
    axis.set_axisbelow(True)
    axis.legend(
        loc="lower center",
        bbox_to_anchor=(0.5, 1.01),
        frameon=False,
        ncol=2,
        fontsize=14,
        borderaxespad=0,
    )
    axis.margins(x=0.08)
    figure.subplots_adjust(top=0.86, bottom=0.14, left=0.18, right=0.98)

    output_dir.mkdir(parents=True, exist_ok=True)
    destinations = []
    for extension in formats:
        destination = output_dir / f"semijoin_comparison.{extension}"
        figure.savefig(destination, dpi=dpi, facecolor="white")
        destinations.append(destination)
    plt.close(figure)
    return destinations, labels, speedups


def parse_args(argv: Optional[Sequence[str]] = None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="comparison CSV")
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
        help="output formats",
    )
    parser.add_argument("--dpi", type=int, default=1200, help="PNG resolution")
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    destinations, labels, speedups = plot(
        args.input.expanduser().resolve(),
        args.output_dir.expanduser().resolve(),
        tuple(dict.fromkeys(args.formats)),
        args.dpi,
    )
    summary = ", ".join(
        f"{label}={speedup:.3f}x" for label, speedup in zip(labels, speedups)
    )
    print(
        f"Q5 Bloom Filter/Hash Filter bars ({summary}) -> "
        + ", ".join(str(path) for path in destinations)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
