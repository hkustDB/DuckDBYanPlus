#!/usr/bin/env python3
"""Run the same Yan+ query with Bloom and Hash and summarize timings."""

import argparse
import csv
import io
import math
import pathlib
import random
import statistics
import subprocess
import sys


HERE = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[1]
BENCHMARKS = {
    "BLOOM": HERE / "semijoin_filter_bloom.benchmark",
    "HASH": HERE / "semijoin_filter_hash.benchmark",
}


def benchmark_selector(benchmark):
    # benchmark_runner registers interpreted benchmarks under repository-relative
    # names even when this comparison script itself was opened through an
    # absolute path.
    return benchmark.relative_to(REPOSITORY_ROOT).as_posix()


def run_command(command):
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise RuntimeError("command failed: " + " ".join(map(str, command)))
    return result


def normalized_query(runner, benchmark):
    query = run_command([str(runner), benchmark_selector(benchmark), "--query"]).stdout
    return " ".join(query.split())


def run_benchmark(runner, benchmark):
    # benchmark_runner prints queries requested with --query to stdout, but its
    # timing table to stderr.
    output = run_command([str(runner), benchmark_selector(benchmark)]).stderr
    timings = []
    # benchmark_runner writes: name<TAB>run<TAB>timing
    for row in csv.reader(io.StringIO(output), delimiter="\t"):
        if len(row) < 3:
            continue
        status = row[-1].strip()
        if status in {"ERROR", "TIMEOUT", "INCORRECT"}:
            raise RuntimeError(f"benchmark failed for {benchmark}: {status}")
        try:
            timings.append(float(status))
        except ValueError:
            continue
    if not timings:
        raise RuntimeError(f"no timing rows produced for {benchmark}")
    return timings


def percentile_95(values):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * 0.95) - 1)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--runner",
        type=pathlib.Path,
        default=pathlib.Path("build/release/benchmark/benchmark_runner"),
        help="path to DuckDB's benchmark_runner",
    )
    parser.add_argument("--seed", type=int, default=15, help="backend execution-order seed")
    parser.add_argument("--output", type=pathlib.Path, help="optional summary CSV")
    args = parser.parse_args()
    args.runner = args.runner.resolve()

    queries = {name: normalized_query(args.runner, path) for name, path in BENCHMARKS.items()}
    if len(set(queries.values())) != 1:
        raise RuntimeError("Bloom and Hash benchmark queries differ")

    order = list(BENCHMARKS)
    random.Random(args.seed).shuffle(order)
    samples = {name: run_benchmark(args.runner, BENCHMARKS[name]) for name in order}
    bloom_median = statistics.median(samples["BLOOM"])

    rows = []
    for backend in ("BLOOM", "HASH"):
        values = samples[backend]
        median = statistics.median(values)
        rows.append(
            {
                "backend": backend,
                "runs": len(values),
                "median_seconds": f"{median:.9f}",
                "p95_seconds": f"{percentile_95(values):.9f}",
                "min_seconds": f"{min(values):.9f}",
                "max_seconds": f"{max(values):.9f}",
                "speedup_vs_bloom": f"{bloom_median / median:.4f}",
            }
        )

    destination = args.output.open("w", newline="") if args.output else sys.stdout
    try:
        writer = csv.DictWriter(destination, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    finally:
        if args.output:
            destination.close()


if __name__ == "__main__":
    main()
