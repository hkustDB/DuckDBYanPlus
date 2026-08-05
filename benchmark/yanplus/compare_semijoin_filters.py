#!/usr/bin/env python3
"""Run paired Yan+ workloads with Bloom and Hash and summarize timings."""

import argparse
import csv
import io
import math
import pathlib
import random
import re
import shutil
import statistics
import subprocess
import sys
from typing import NamedTuple


HERE = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[1]
BACKENDS = ("BLOOM", "HASH")
WORKLOADS = {
    "cyclic_triangle": {
        "description": "selective three-relation cycle",
        "topology": "cyclic_triangle",
        "key_shape": "two_integer_composite",
        "expected_filter_pairs": 1,
        "benchmarks": {
            "BLOOM": HERE / "semijoin_filter_bloom.benchmark",
            "HASH": HERE / "semijoin_filter_hash.benchmark",
        },
    },
    "acyclic_chain": {
        "description": "four-relation chain with three cascading filters",
        "topology": "acyclic_chain",
        "key_shape": "single_bigint",
        "expected_filter_pairs": 3,
        "benchmarks": {
            "BLOOM": HERE / "semijoin_filter_acyclic_chain_bloom.benchmark",
            "HASH": HERE / "semijoin_filter_acyclic_chain_hash.benchmark",
        },
    },
    "acyclic_skewed_star": {
        "description": "skewed fact table with three selective dimensions",
        "topology": "acyclic_star",
        "key_shape": "single_integer",
        "expected_filter_pairs": 3,
        "benchmarks": {
            "BLOOM": HERE / "semijoin_filter_acyclic_skewed_star_bloom.benchmark",
            "HASH": HERE / "semijoin_filter_acyclic_skewed_star_hash.benchmark",
        },
    },
    "cyclic_four_cycle": {
        "description": "four-relation cyclic core with an acyclic tail",
        "topology": "cyclic_four_cycle_with_tail",
        "key_shape": "integer_composite",
        "expected_filter_pairs": 1,
        "benchmarks": {
            "BLOOM": HERE / "semijoin_filter_cyclic_four_cycle_bloom.benchmark",
            "HASH": HERE / "semijoin_filter_cyclic_four_cycle_hash.benchmark",
        },
    },
    "cyclic_wide_composite": {
        "description": "large cyclic build with mixed VARCHAR and BIGINT keys",
        "topology": "cyclic_triangle",
        "key_shape": "varchar_bigint_composite",
        "expected_filter_pairs": 1,
        "benchmarks": {
            "BLOOM": HERE / "semijoin_filter_cyclic_wide_composite_bloom.benchmark",
            "HASH": HERE / "semijoin_filter_cyclic_wide_composite_hash.benchmark",
        },
    },
    "cyclic_skew_duplicates": {
        "description": "duplicate-heavy cyclic build with few distinct composite keys",
        "topology": "cyclic_triangle",
        "key_shape": "duplicate_integer_composite",
        "expected_filter_pairs": 1,
        "benchmarks": {
            "BLOOM": HERE / "semijoin_filter_cyclic_skew_duplicates_bloom.benchmark",
            "HASH": HERE / "semijoin_filter_cyclic_skew_duplicates_hash.benchmark",
        },
    },
}
DEFAULT_THREADS = 64
DEFAULT_CPU_LIST = "0-31,36-67"
DEFAULT_SINGLE_CPU = 0
CSV_FIELDS = (
    "workload",
    "description",
    "topology",
    "key_shape",
    "expected_filter_pairs",
    "benchmark",
    "configuration",
    "threads",
    "cpu_list",
    "backend",
    "runs",
    "median_seconds",
    "p95_seconds",
    "min_seconds",
    "max_seconds",
    "speedup_vs_bloom",
    "speedup_vs_single_thread",
)


class ExecutionProfile(NamedTuple):
    configuration: str
    threads: int
    cpu_list: str


def benchmark_name(benchmark):
    # benchmark_runner registers interpreted benchmarks under repository-relative
    # names even when this comparison script itself was opened through an
    # absolute path.
    return benchmark.relative_to(REPOSITORY_ROOT).as_posix()


def benchmark_selector(benchmark):
    # benchmark_runner treats its positional selector as a regular expression.
    # Anchor and escape it so one requested case cannot select another case.
    return "^" + re.escape(benchmark_name(benchmark)) + "$"


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


def selected_workloads(parser, selections):
    if not selections:
        return list(WORKLOADS)

    result = []
    for selection in selections:
        for item in selection.split(","):
            workload = item.strip().lower()
            if not workload:
                parser.error("--workload contains an empty name")
            if workload == "all":
                candidates = WORKLOADS
            elif workload in WORKLOADS:
                candidates = (workload,)
            else:
                parser.error(
                    f"unknown workload '{workload}'; use --list-workloads to show valid names"
                )
            for candidate in candidates:
                if candidate not in result:
                    result.append(candidate)
    return result


def comparable_benchmark_definition(benchmark):
    result = []
    for line in benchmark.read_text(encoding="utf-8").splitlines():
        normalized = line.strip().lower()
        if normalized.startswith("# name:") or normalized.startswith("# description:"):
            continue
        if normalized.startswith("name "):
            continue
        if normalized.startswith("set yanplus_semijoin_filter"):
            result.append("SET yanplus_semijoin_filter = '<backend>';")
        else:
            result.append(line.rstrip())
    return "\n".join(result).strip()


def validate_workload_pair(workload, benchmarks):
    for backend in BACKENDS:
        benchmark = benchmarks[backend]
        if not benchmark.is_file():
            raise RuntimeError(f"missing {backend} benchmark for {workload}: {benchmark}")
        settings = re.findall(
            r"^\s*SET\s+yanplus_semijoin_filter\s*=\s*'([^']+)'\s*;\s*$",
            benchmark.read_text(encoding="utf-8"),
            flags=re.IGNORECASE | re.MULTILINE,
        )
        if [setting.upper() for setting in settings] != [backend]:
            raise RuntimeError(
                f"{benchmark} must set yanplus_semijoin_filter exactly once to {backend}"
            )
    definitions = {
        backend: comparable_benchmark_definition(benchmarks[backend]) for backend in BACKENDS
    }
    if len(set(definitions.values())) != 1:
        raise RuntimeError(
            f"Bloom and Hash benchmark definitions differ outside backend metadata for {workload}"
        )


def benchmark_command(args, profile, benchmark, *extra):
    return [
        args.taskset,
        "--cpu-list",
        profile.cpu_list,
        str(args.runner),
        benchmark_selector(benchmark),
        f"--threads={profile.threads}",
        *extra,
    ]


def normalized_query(args, profile, benchmark):
    query = run_command(benchmark_command(args, profile, benchmark, "--query")).stdout
    return " ".join(query.split())


def run_benchmark(args, profile, benchmark):
    # benchmark_runner prints queries requested with --query to stdout, but its
    # timing table to stderr.
    output = run_command(benchmark_command(args, profile, benchmark)).stderr
    timings = []
    # benchmark_runner writes: name<TAB>run<TAB>timing
    for row in csv.reader(io.StringIO(output), delimiter="\t"):
        if len(row) < 3:
            continue
        if row[0].strip() != benchmark_name(benchmark):
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


def validate_profile(parser, args, profile):
    try:
        cpu_count = len(selected_cpu_ids(profile.cpu_list))
    except ValueError as error:
        parser.error(f"{profile.configuration}: {error}")
    if cpu_count != profile.threads:
        parser.error(
            f"{profile.configuration}: --cpu-list selects {cpu_count} CPUs but "
            f"the profile uses {profile.threads} DuckDB thread(s)"
        )

    try:
        output = run_command([args.taskset, "--cpu-list", profile.cpu_list, "nproc"]).stdout.strip()
        available_cpu_count = int(output)
    except (RuntimeError, ValueError):
        parser.error(
            f"{profile.configuration}: could not validate CPU affinity with taskset and nproc"
        )
    if available_cpu_count != profile.threads:
        parser.error(
            f"{profile.configuration}: taskset exposes {available_cpu_count} CPUs, "
            f"expected {profile.threads}; check the host CPU IDs and cpuset/cgroup limits"
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--runner",
        type=pathlib.Path,
        default=pathlib.Path("build/release/benchmark/benchmark_runner"),
        help="path to DuckDB's benchmark_runner",
    )
    parser.add_argument(
        "--multi-threads",
        "--threads",
        dest="multi_threads",
        type=int,
        default=DEFAULT_THREADS,
        help=(
            "DuckDB threads and required CPU count for the multi-thread profile "
            f"(default: {DEFAULT_THREADS})"
        ),
    )
    parser.add_argument(
        "--multi-cpu-list",
        "--cpu-list",
        dest="multi_cpu_list",
        default=DEFAULT_CPU_LIST,
        help=(
            "Linux taskset logical CPU list for the multi-thread profile "
            f"(default: {DEFAULT_CPU_LIST})"
        ),
    )
    parser.add_argument(
        "--single-cpu",
        type=int,
        default=DEFAULT_SINGLE_CPU,
        help=f"fixed logical CPU for the single-thread profile (default: {DEFAULT_SINGLE_CPU})",
    )
    parser.add_argument(
        "--workload",
        "--workloads",
        dest="workload_selections",
        action="append",
        help="workload name or comma-separated names; repeatable (default: all)",
    )
    parser.add_argument(
        "--list-workloads",
        action="store_true",
        help="list workload names and exit",
    )
    parser.add_argument(
        "--taskset",
        default="taskset",
        help="taskset executable name or path (default: taskset)",
    )
    parser.add_argument("--seed", type=int, default=15, help="workload/backend execution-order seed")
    parser.add_argument("--output", type=pathlib.Path, help="optional summary CSV")
    args = parser.parse_args()
    if args.list_workloads:
        for workload, definition in WORKLOADS.items():
            print(f"{workload}\t{definition['description']}")
        return

    workloads = selected_workloads(parser, args.workload_selections)
    args.runner = args.runner.resolve()

    if not args.runner.is_file():
        parser.error(f"benchmark runner does not exist: {args.runner}")
    if args.multi_threads < 2:
        parser.error("--multi-threads/--threads must be at least 2")
    if args.single_cpu < 0:
        parser.error("--single-cpu must be non-negative")
    taskset_path = shutil.which(args.taskset)
    if taskset_path is None:
        parser.error("taskset was not found; install util-linux and run this experiment on Linux")
    args.taskset = taskset_path

    try:
        multi_cpu_ids = selected_cpu_ids(args.multi_cpu_list)
    except ValueError as error:
        parser.error(str(error))
    if args.single_cpu not in multi_cpu_ids:
        parser.error("--single-cpu must also be selected by --multi-cpu-list/--cpu-list")

    profiles = (
        ExecutionProfile("single_thread", 1, str(args.single_cpu)),
        ExecutionProfile("multi_thread", args.multi_threads, args.multi_cpu_list),
    )
    for profile in profiles:
        validate_profile(parser, args, profile)

    queries = {}
    for workload in workloads:
        benchmarks = WORKLOADS[workload]["benchmarks"]
        validate_workload_pair(workload, benchmarks)
        queries[workload] = {
            backend: normalized_query(args, profiles[0], benchmarks[backend])
            for backend in BACKENDS
        }
        if len(set(queries[workload].values())) != 1:
            raise RuntimeError(f"Bloom and Hash benchmark queries differ for {workload}")

    randomizer = random.Random(args.seed)
    blocks = [(workload, profile) for workload in workloads for profile in profiles]
    randomizer.shuffle(blocks)
    order = []
    for workload, profile in blocks:
        backends = list(BACKENDS)
        randomizer.shuffle(backends)
        order.extend((workload, profile, backend) for backend in backends)

    samples = {}
    for workload, profile, backend in order:
        print(
            f"Running {workload}/{backend} with {profile.configuration}: "
            f"threads={profile.threads}, cpu_list={profile.cpu_list}",
            file=sys.stderr,
        )
        benchmark = WORKLOADS[workload]["benchmarks"][backend]
        samples[(workload, profile.configuration, backend)] = run_benchmark(args, profile, benchmark)

    single_medians = {
        (workload, backend): statistics.median(
            samples[(workload, profiles[0].configuration, backend)]
        )
        for workload in workloads
        for backend in BACKENDS
    }

    rows = []
    for workload in workloads:
        definition = WORKLOADS[workload]
        for profile in profiles:
            bloom_median = statistics.median(
                samples[(workload, profile.configuration, "BLOOM")]
            )
            for backend in BACKENDS:
                values = samples[(workload, profile.configuration, backend)]
                median = statistics.median(values)
                rows.append(
                    {
                        "workload": workload,
                        "description": definition["description"],
                        "topology": definition["topology"],
                        "key_shape": definition["key_shape"],
                        "expected_filter_pairs": definition["expected_filter_pairs"],
                        "benchmark": benchmark_name(definition["benchmarks"][backend]),
                        "configuration": profile.configuration,
                        "threads": profile.threads,
                        "cpu_list": profile.cpu_list,
                        "backend": backend,
                        "runs": len(values),
                        "median_seconds": f"{median:.9f}",
                        "p95_seconds": f"{percentile_95(values):.9f}",
                        "min_seconds": f"{min(values):.9f}",
                        "max_seconds": f"{max(values):.9f}",
                        "speedup_vs_bloom": f"{bloom_median / median:.4f}",
                        "speedup_vs_single_thread": (
                            f"{single_medians[(workload, backend)] / median:.4f}"
                        ),
                    }
                )

    destination = args.output.open("w", newline="") if args.output else sys.stdout
    try:
        writer = csv.DictWriter(destination, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    finally:
        if args.output:
            destination.close()


if __name__ == "__main__":
    main()
