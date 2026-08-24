#!/usr/bin/env python3
"""Summarize robustness timings relative to each query's DuckDB plan."""

from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
import statistics
import sys
from collections import defaultdict


PLAN_FIELDS = (
    "suite",
    "query",
    "plan",
    "status",
    "validation_status",
    "matches_original",
    "original_status",
    "n",
    "mean_s",
    "median_s",
    "stdev_s",
    "min_s",
    "p05_s",
    "p95_s",
    "max_s",
    "cv_pct",
    "original_n",
    "original_mean_s",
    "original_median_s",
    "original_min_s",
    "original_timeout_lower_bound_s",
    "speedup_mean",
    "speedup_median",
    "speedup_worst_case",
    "speedup_lower_bound_worst_case",
    "improvement_mean_pct",
    "improvement_median_pct",
    "faster_by_mean",
    "faster_by_median",
    "steady_beats_original",
)

ROBUST_QUERY_FIELDS = (
    "Query",
    "Original (s)",
    "Rewrite average (s)",
    "Rewrite median (s)",
    "Fastest rewrite (s)",
    "Slowest rewrite (s)",
    "Rewrite run std (s)",
    "# Rewrite Plan",
)


def read_csv(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as source:
        return list(csv.DictReader(source))


def percentile(values: list[float], quantile: float) -> float:
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * quantile
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] * (1.0 - fraction) + ordered[upper] * fraction


def describe(values: list[float]) -> dict[str, float | int]:
    average = statistics.mean(values)
    deviation = statistics.stdev(values) if len(values) > 1 else 0.0
    return {
        "n": len(values),
        "mean_s": average,
        "median_s": statistics.median(values),
        "stdev_s": deviation,
        "min_s": min(values),
        "p05_s": percentile(values, 0.05),
        "p95_s": percentile(values, 0.95),
        "max_s": max(values),
        "cv_pct": 100.0 * deviation / average if average else 0.0,
    }


def geometric_mean(values: list[float]) -> float:
    return math.exp(statistics.mean(math.log(value) for value in values))


def number(value: float | int | None, digits: int = 9) -> str:
    if value is None:
        return ""
    if isinstance(value, int):
        return str(value)
    return f"{value:.{digits}f}"


def truth(value: bool) -> str:
    return "true" if value else "false"


def write_csv(path: pathlib.Path, fields: tuple[str, ...], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as destination:
        writer = csv.DictWriter(destination, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})


def load_expected_repetitions(raw_path: pathlib.Path, grouped: dict[tuple[str, str, str], list[float]]) -> int:
    metadata_path = raw_path.parent / "metadata.json"
    if metadata_path.is_file():
        try:
            value = int(json.loads(metadata_path.read_text(encoding="utf-8"))["repetitions"])
            if value > 0:
                return value
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            pass
    return max((len(values) for values in grouped.values()), default=0)


def load_timeout_seconds(raw_path: pathlib.Path) -> int | None:
    metadata_path = raw_path.parent / "metadata.json"
    if metadata_path.is_file():
        try:
            value = int(json.loads(metadata_path.read_text(encoding="utf-8"))["timeout_seconds"])
            if value > 0:
                return value
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            pass
    return None


def summarize(
    raw_path: pathlib.Path, validation_path: pathlib.Path, output_directory: pathlib.Path
) -> dict[str, object]:
    raw_rows = read_csv(raw_path)
    validation_rows = read_csv(validation_path)
    grouped: dict[tuple[str, str, str], list[float]] = defaultdict(list)
    for row in raw_rows:
        if row.get("status") != "ok" or not row.get("seconds"):
            continue
        grouped[(row["suite"], row["query"], row["plan"])].append(float(row["seconds"]))

    expected_repetitions = load_expected_repetitions(raw_path, grouped)
    timeout_seconds = load_timeout_seconds(raw_path)
    validation = {
        (row["suite"], row["query"], row["plan"]): row for row in validation_rows
    }
    rewrite_keys = sorted(
        (
            key
            for key, row in validation.items()
            if row.get("plan_kind") == "rewrite"
        ),
        key=lambda key: (key[0], key[1], int(key[2][len("rewrite") :])),
    )

    plan_rows: list[dict[str, object]] = []
    for suite, query, plan in rewrite_keys:
        key = (suite, query, plan)
        original_key = (suite, query, "query")
        rewrite_validation = validation[key]
        original_validation = validation.get(original_key)
        values = grouped.get(key, [])
        original_values = grouped.get(original_key, [])
        semantic_ok = (
            rewrite_validation.get("status") == "ok"
            and rewrite_validation.get("matches_original") == "true"
            and original_validation is not None
            and original_validation.get("status") == "ok"
        )
        rewrite_timing_complete = (
            rewrite_validation.get("status") in {"ok", "unverified"}
            and expected_repetitions > 0
            and len(values) == expected_repetitions
        )
        original_timing_complete = (
            original_validation is not None
            and original_validation.get("status") == "ok"
            and expected_repetitions > 0
            and len(original_values) == expected_repetitions
        )
        complete = semantic_ok and rewrite_timing_complete and original_timing_complete
        unverified_complete = (
            rewrite_validation.get("status") == "unverified"
            and rewrite_timing_complete
            and original_validation is not None
            and original_validation.get("status") != "ok"
        )
        if complete:
            status = "measured"
        elif unverified_complete:
            status = "measured_original_unavailable"
        else:
            status = "incomplete"
        row: dict[str, object] = {
            "suite": suite,
            "query": query,
            "plan": plan,
            "status": status,
            "validation_status": rewrite_validation.get("status", "missing"),
            "matches_original": rewrite_validation.get("matches_original") == "true",
            "original_status": (
                original_validation.get("status", "missing")
                if original_validation is not None
                else "missing"
            ),
            "n": len(values),
            "original_n": len(original_values),
            "faster_by_mean": False,
            "faster_by_median": False,
            "steady_beats_original": False,
        }
        if values:
            row.update(describe(values))
        if original_values:
            original_stats = describe(original_values)
            row["original_mean_s"] = original_stats["mean_s"]
            row["original_median_s"] = original_stats["median_s"]
            row["original_min_s"] = original_stats["min_s"]
        if (
            original_validation is not None
            and original_validation.get("status") == "timeout"
            and timeout_seconds is not None
        ):
            row["original_timeout_lower_bound_s"] = timeout_seconds
        if complete:
            mean_speedup = float(row["original_mean_s"]) / float(row["mean_s"])
            median_speedup = float(row["original_median_s"]) / float(row["median_s"])
            worst_case_speedup = float(row["original_min_s"]) / float(row["max_s"])
            row.update(
                {
                    "speedup_mean": mean_speedup,
                    "speedup_median": median_speedup,
                    "speedup_worst_case": worst_case_speedup,
                    "improvement_mean_pct": 100.0 * (1.0 - 1.0 / mean_speedup),
                    "improvement_median_pct": 100.0 * (1.0 - 1.0 / median_speedup),
                    "faster_by_mean": mean_speedup > 1.0,
                    "faster_by_median": median_speedup > 1.0,
                    "steady_beats_original": worst_case_speedup > 1.0,
                }
            )
        elif unverified_complete and timeout_seconds is not None and row["original_status"] == "timeout":
            lower_bound_speedup = timeout_seconds / float(row["max_s"])
            row["speedup_lower_bound_worst_case"] = lower_bound_speedup
            row["steady_beats_original"] = lower_bound_speedup > 1.0
        plan_rows.append(row)

    output_directory.mkdir(parents=True, exist_ok=True)
    serialized_plan_rows = []
    for row in plan_rows:
        serialized = dict(row)
        for field in PLAN_FIELDS:
            value = serialized.get(field)
            if isinstance(value, bool):
                serialized[field] = truth(value)
            elif isinstance(value, float):
                serialized[field] = number(value)
        serialized_plan_rows.append(serialized)
    write_csv(output_directory / "plan_statistics.csv", PLAN_FIELDS, serialized_plan_rows)

    plans_by_query: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in plan_rows:
        plans_by_query[(str(row["suite"]), str(row["query"]))].append(row)

    query_fields = (
        "suite",
        "query",
        "rewrite_count",
        "measured_count",
        "wins_by_mean",
        "wins_by_median",
        "all_faster_by_mean",
        "all_faster_by_median",
        "mean_of_median_speedups",
        "median_of_median_speedups",
        "geomean_of_median_speedups",
        "min_median_speedup",
        "max_median_speedup",
    )
    query_rows: list[dict[str, object]] = []
    for (suite, query), rows in sorted(plans_by_query.items()):
        measured = [row for row in rows if row["status"] == "measured"]
        speedups = [float(row["speedup_median"]) for row in measured]
        wins_mean = sum(bool(row["faster_by_mean"]) for row in measured)
        wins_median = sum(bool(row["faster_by_median"]) for row in measured)
        query_row: dict[str, object] = {
            "suite": suite,
            "query": query,
            "rewrite_count": len(rows),
            "measured_count": len(measured),
            "wins_by_mean": wins_mean,
            "wins_by_median": wins_median,
            "all_faster_by_mean": len(measured) == len(rows) and wins_mean == len(rows),
            "all_faster_by_median": len(measured) == len(rows) and wins_median == len(rows),
        }
        if speedups:
            query_row.update(
                {
                    "mean_of_median_speedups": statistics.mean(speedups),
                    "median_of_median_speedups": statistics.median(speedups),
                    "geomean_of_median_speedups": geometric_mean(speedups),
                    "min_median_speedup": min(speedups),
                    "max_median_speedup": max(speedups),
                }
            )
        query_rows.append(query_row)

    serialized_query_rows = []
    for row in query_rows:
        serialized = {}
        for field, value in row.items():
            if isinstance(value, bool):
                serialized[field] = truth(value)
            elif isinstance(value, float):
                serialized[field] = number(value, 6)
            else:
                serialized[field] = value
        serialized_query_rows.append(serialized)
    write_csv(output_directory / "query_summary.csv", query_fields, serialized_query_rows)

    robust_query_rows: list[dict[str, object]] = []
    for (suite, query), rows in sorted(plans_by_query.items()):
        retained = [
            row
            for row in rows
            if row["status"] in {"measured", "measured_original_unavailable"}
            and bool(row["steady_beats_original"])
        ]
        if not retained:
            continue
        retained_values = [
            value
            for row in retained
            for value in grouped[(suite, query, str(row["plan"]))]
        ]
        retained_stats = describe(retained_values)
        original_unavailable = any(
            row["status"] == "measured_original_unavailable" for row in retained
        )
        if original_unavailable:
            original_execution_time = timeout_seconds
        else:
            original_execution_time = float(retained[0]["original_median_s"])
        robust_query_rows.append(
            {
                "Query": f"{suite}-{query}",
                "Original (s)": original_execution_time,
                "Rewrite average (s)": retained_stats["mean_s"],
                "Rewrite median (s)": retained_stats["median_s"],
                "Fastest rewrite (s)": retained_stats["min_s"],
                "Slowest rewrite (s)": retained_stats["max_s"],
                "Rewrite run std (s)": retained_stats["stdev_s"],
                "# Rewrite Plan": len(retained),
            }
        )

    serialized_robust_query_rows = []
    for row in robust_query_rows:
        serialized = {}
        for field, value in row.items():
            if isinstance(value, bool):
                serialized[field] = truth(value)
            elif isinstance(value, float):
                serialized[field] = number(value, 6)
            else:
                serialized[field] = value
        serialized_robust_query_rows.append(serialized)
    write_csv(
        output_directory / "robust_query_statistics.csv",
        ROBUST_QUERY_FIELDS,
        serialized_robust_query_rows,
    )

    measured = [row for row in plan_rows if row["status"] == "measured"]
    median_speedups = [float(row["speedup_median"]) for row in measured]
    mean_speedups = [float(row["speedup_mean"]) for row in measured]
    wins_mean = sum(bool(row["faster_by_mean"]) for row in measured)
    wins_median = sum(bool(row["faster_by_median"]) for row in measured)
    expected_count = len(plan_rows)
    overall: dict[str, object] = {
        "expected_rewrite_plans": expected_count,
        "measured_rewrite_plans": len(measured),
        "wins_by_mean": wins_mean,
        "wins_by_median": wins_median,
        "all_plans_outperform_by_mean": len(measured) == expected_count and wins_mean == expected_count,
        "all_plans_outperform_by_median": len(measured) == expected_count and wins_median == expected_count,
    }
    if median_speedups:
        overall.update(
            {
                "mean_of_median_speedups": statistics.mean(median_speedups),
                "median_of_median_speedups": statistics.median(median_speedups),
                "geomean_of_median_speedups": geometric_mean(median_speedups),
                "p05_median_speedup": percentile(median_speedups, 0.05),
                "p95_median_speedup": percentile(median_speedups, 0.95),
                "min_median_speedup": min(median_speedups),
                "max_median_speedup": max(median_speedups),
                "mean_of_mean_speedups": statistics.mean(mean_speedups),
                "median_of_mean_speedups": statistics.median(mean_speedups),
                "geomean_of_mean_speedups": geometric_mean(mean_speedups),
            }
        )

    overall_rows = []
    for metric, value in overall.items():
        if isinstance(value, bool):
            rendered = truth(value)
        elif isinstance(value, float):
            rendered = number(value, 6)
        else:
            rendered = str(value)
        overall_rows.append({"metric": metric, "value": rendered})
    write_csv(output_directory / "overall_summary.csv", ("metric", "value"), overall_rows)

    conclusion = (
        "All measured rewrite plans outperform their original DuckDB plans by median runtime."
        if overall["all_plans_outperform_by_median"]
        else "The data do not support the claim that every rewrite plan outperforms its original DuckDB plan."
    )
    markdown = [
        "# Robustness experiment summary",
        "",
        conclusion,
        "",
        f"- Expected rewrite plans: {expected_count}",
        f"- Completely measured plans: {len(measured)}",
        f"- Faster by median: {wins_median}/{expected_count}",
        f"- Faster by arithmetic mean: {wins_mean}/{expected_count}",
        f"- All faster by median: {truth(bool(overall['all_plans_outperform_by_median']))}",
        f"- All faster by mean: {truth(bool(overall['all_plans_outperform_by_mean']))}",
    ]
    if median_speedups:
        markdown.extend(
            [
                f"- Median plan speedup (from plan medians): {statistics.median(median_speedups):.3f}x",
                f"- Arithmetic mean plan speedup: {statistics.mean(median_speedups):.3f}x",
                f"- Geometric mean plan speedup: {geometric_mean(median_speedups):.3f}x",
                f"- Minimum / p05 / p95 / maximum speedup: {min(median_speedups):.3f}x / "
                f"{percentile(median_speedups, 0.05):.3f}x / "
                f"{percentile(median_speedups, 0.95):.3f}x / {max(median_speedups):.3f}x",
            ]
        )
    markdown.extend(
        [
            "",
            "The primary robustness criterion is strict: every expected rewrite must pass exact-result validation, "
            "finish every repetition, and have a median runtime below the corresponding original median.",
            "",
        ]
    )
    (output_directory / "summary.md").write_text("\n".join(markdown), encoding="utf-8")
    return overall


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw_results", type=pathlib.Path)
    parser.add_argument("validation", type=pathlib.Path)
    parser.add_argument("--output-dir", type=pathlib.Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    raw_path = args.raw_results.resolve()
    validation_path = args.validation.resolve()
    output_directory = (args.output_dir or raw_path.parent).resolve()
    if not raw_path.is_file() or not validation_path.is_file():
        print("error: raw results and validation CSV files are required", file=sys.stderr)
        return 2
    try:
        overall = summarize(raw_path, validation_path, output_directory)
    except (OSError, ValueError, KeyError, statistics.StatisticsError) as error:
        print(f"error: cannot summarize results: {error}", file=sys.stderr)
        return 1
    print(f"Wrote robustness statistics to {output_directory}")
    print(
        "All plans outperform by median: "
        f"{truth(bool(overall['all_plans_outperform_by_median']))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
