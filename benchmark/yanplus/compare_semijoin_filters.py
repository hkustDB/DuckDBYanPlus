#!/usr/bin/env python3
"""Run the same Yan+ query with Bloom and Hash and summarize timings."""

import argparse
import csv
import io
import math
import pathlib
import random
import shutil
import statistics
import subprocess
import sys


HERE = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[1]
BENCHMARKS = {
    "BLOOM": HERE / "semijoin_filter_bloom.benchmark",
    "HASH": HERE / "semijoin_filter_hash.benchmark",
}
DEFAULT_THREADS = 64
DEFAULT_CPU_LIST = "0-63"


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


def selected_cpu_ids(cpu_list):
    result = set()
    for item in cpu_list.split(","):
        item = item.strip()
        if not item:
            raise ValueError("empty CPU-list component")
        if "-" in item:
            bounds = item.split("-")
            if len(bounds) != 2:
                raise ValueError(f"unsupported CPU range: {item}")
            first, last = (int(bound) for bound in bounds)
            if first < 0 or last < first:
                raise ValueError(f"invalid CPU range: {item}")
            result.update(range(first, last + 1))
        else:
            cpu_id = int(item)
            if cpu_id < 0:
                raise ValueError(f"invalid CPU ID: {item}")
            result.add(cpu_id)
    return result


def benchmark_command(args, benchmark, *extra):
    return [
        args.taskset,
        "--cpu-list",
        args.cpu_list,
        str(args.runner),
        benchmark_selector(benchmark),
        f"--threads={args.threads}",
        *extra,
    ]


def normalized_query(args, benchmark):
    query = run_command(benchmark_command(args, benchmark, "--query")).stdout
    return " ".join(query.split())


def run_benchmark(args, benchmark):
    # benchmark_runner prints queries requested with --query to stdout, but its
    # timing table to stderr.
    output = run_command(benchmark_command(args, benchmark)).stderr
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
    parser.add_argument(
        "--threads",
        type=int,
        default=DEFAULT_THREADS,
        help=f"DuckDB threads and required CPU count (default: {DEFAULT_THREADS})",
    )
    parser.add_argument(
        "--cpu-list",
        default=DEFAULT_CPU_LIST,
        help=f"Linux taskset logical CPU list (default: {DEFAULT_CPU_LIST})",
    )
    parser.add_argument(
        "--taskset",
        default="taskset",
        help="taskset executable name or path (default: taskset)",
    )
    parser.add_argument("--seed", type=int, default=15, help="backend execution-order seed")
    parser.add_argument("--output", type=pathlib.Path, help="optional summary CSV")
    args = parser.parse_args()
    args.runner = args.runner.resolve()

    if not args.runner.is_file():
        parser.error(f"benchmark runner does not exist: {args.runner}")
    if args.threads < 1:
        parser.error("--threads must be positive")
    taskset_path = shutil.which(args.taskset)
    if taskset_path is None:
        parser.error("taskset was not found; install util-linux and run this experiment on Linux")
    args.taskset = taskset_path
    try:
        cpu_count = len(selected_cpu_ids(args.cpu_list))
    except ValueError as error:
        parser.error(str(error))
    if cpu_count != args.threads:
        parser.error(f"--cpu-list selects {cpu_count} CPUs but --threads is {args.threads}")

    available_cpu_count = int(
        run_command([args.taskset, "--cpu-list", args.cpu_list, "nproc"]).stdout.strip()
    )
    if available_cpu_count != args.threads:
        parser.error(
            f"taskset exposes {available_cpu_count} CPUs, expected {args.threads}; "
            "check the host CPU IDs and cpuset/cgroup limits"
        )

    queries = {name: normalized_query(args, path) for name, path in BENCHMARKS.items()}
    if len(set(queries.values())) != 1:
        raise RuntimeError("Bloom and Hash benchmark queries differ")

    order = list(BENCHMARKS)
    random.Random(args.seed).shuffle(order)
    samples = {name: run_benchmark(args, BENCHMARKS[name]) for name in order}
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
