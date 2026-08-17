#!/usr/bin/env python3
"""Compare Yan+ Bloom and exact Hash filters on the LSQB Q5 sweep."""

import argparse
import csv
import math
import os
import pathlib
import random
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
from typing import NamedTuple, Optional


HERE = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[1]
BACKENDS = ("BLOOM", "HASH")
DEFAULT_THREADS = 64
DEFAULT_CPU_LIST = "0-31,36-67"
DEFAULT_REPETITIONS = 5
TIMER_PATTERN = re.compile(
    r"^Run Time \(s\): real\s+([0-9]+(?:\.[0-9]+)?)\b", re.MULTILINE
)
COUNT_PROJECTION_PATTERN = re.compile(
    r"\A(?P<leading>\s*)SELECT\s+count\s*\(\s*\*\s*\)", re.IGNORECASE
)
CSV_FIELDS = (
    "query",
    "query_file",
    "predicate",
    "expected_selectivity_pct",
    "database",
    "threads",
    "cpu_list",
    "repetitions",
    "bloom_median_seconds",
    "bloom_p95_seconds",
    "bloom_min_seconds",
    "bloom_max_seconds",
    "hash_median_seconds",
    "hash_p95_seconds",
    "hash_min_seconds",
    "hash_max_seconds",
    "hash_speedup_vs_bloom",
    "bloom_speedup_vs_hash",
    "faster_backend",
    "bloom_samples_seconds",
    "hash_samples_seconds",
)


class Workload(NamedTuple):
    name: str
    query_file: pathlib.Path
    database_name: str
    original_query_file: Optional[pathlib.Path] = None
    unary_predicate: Optional[str] = None
    expected_selectivity_pct: Optional[float] = None
    replace_count_projection: bool = True


WORKLOADS = {
    "lsqb_q5": Workload(
        "lsqb_q5",
        HERE / "queries/lsqb_q5_select_all.sql",
        "lsqb_db",
        REPOSITORY_ROOT / "lsqb/q5.sql",
        expected_selectivity_pct=100.0,
    ),
    "q5_predicate_50pct": Workload(
        "q5_predicate_50pct",
        HERE / "queries/q5_predicate_50pct.sql",
        "lsqb_db",
        REPOSITORY_ROOT / "lsqb/q5.sql",
        "Message_hasTag_Tag_T.MessageId % 2 = 0",
        50.0,
    ),
    "q5_predicate_20pct": Workload(
        "q5_predicate_20pct",
        HERE / "queries/q5_predicate_20pct.sql",
        "lsqb_db",
        REPOSITORY_ROOT / "lsqb/q5.sql",
        "Message_hasTag_Tag_T.MessageId % 5 = 0",
        20.0,
    ),
    "q5_predicate": Workload(
        "q5_predicate",
        HERE / "queries/q5_predicate.sql",
        "lsqb_db",
        REPOSITORY_ROOT / "lsqb/q5.sql",
        "Message_hasTag_Tag_T.MessageId % 10 = 0",
        10.0,
    ),
    "q5_predicate_05pct": Workload(
        "q5_predicate_05pct",
        HERE / "queries/q5_predicate_05pct.sql",
        "lsqb_db",
        REPOSITORY_ROOT / "lsqb/q5.sql",
        "Message_hasTag_Tag_T.MessageId % 20 = 0",
        5.0,
    ),
    "q5_predicate_02pct": Workload(
        "q5_predicate_02pct",
        HERE / "queries/q5_predicate_02pct.sql",
        "lsqb_db",
        REPOSITORY_ROOT / "lsqb/q5.sql",
        "Message_hasTag_Tag_T.MessageId % 50 = 0",
        2.0,
    ),
    "q5_predicate_01pct": Workload(
        "q5_predicate_01pct",
        HERE / "queries/q5_predicate_01pct.sql",
        "lsqb_db",
        REPOSITORY_ROOT / "lsqb/q5.sql",
        "Message_hasTag_Tag_T.MessageId % 100 = 0",
        1.0,
    ),
}

WORKLOAD_GROUPS = {
    "q5_sweep": (
        "lsqb_q5",
        "q5_predicate_50pct",
        "q5_predicate_20pct",
        "q5_predicate",
        "q5_predicate_05pct",
        "q5_predicate_02pct",
        "q5_predicate_01pct",
    ),
}


def command_text(command):
    return " ".join(map(str, command))


def run_command(command, timeout_seconds, description):
    try:
        result = subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(
            f"{description} exceeded the {timeout_seconds}-second timeout"
        ) from error
    if result.returncode:
        if result.stdout:
            sys.stderr.write(result.stdout)
        if result.stderr:
            sys.stderr.write(result.stderr)
        raise RuntimeError(
            f"{description} failed with exit {result.returncode}: {command_text(command)}"
        )
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
        return list(WORKLOADS.values())

    names = []
    for selection in selections:
        for item in selection.split(","):
            name = item.strip().lower()
            if name in WORKLOAD_GROUPS:
                candidates = WORKLOAD_GROUPS[name]
            elif name in WORKLOADS:
                candidates = (name,)
            else:
                parser.error(
                    f"unknown query/group '{name}'; choose from "
                    f"{', '.join((*WORKLOADS, *WORKLOAD_GROUPS))}"
                )
            for candidate in candidates:
                if candidate not in names:
                    names.append(candidate)
    return [WORKLOADS[name] for name in names]


def read_query(workload):
    if not workload.query_file.is_file():
        raise RuntimeError(f"query file does not exist: {workload.query_file}")
    query = workload.query_file.read_text(encoding="utf-8")
    if not query.strip():
        raise RuntimeError(f"query file is empty: {workload.query_file}")

    # Predicate variants are intentionally minimal edits of their source query.
    # Refuse to benchmark them if any other part has drifted.
    if workload.original_query_file is not None:
        original = workload.original_query_file.read_text(encoding="utf-8")
        if workload.replace_count_projection:
            expected, replacements = COUNT_PROJECTION_PATTERN.subn(
                lambda match: match.group("leading") + "SELECT *", original, count=1
            )
            if replacements != 1:
                raise RuntimeError(
                    f"expected one leading SELECT count(*) in {workload.original_query_file}"
                )
        else:
            expected = original
        if workload.unary_predicate is not None:
            expected = expected.rstrip() + f"\n\tAND {workload.unary_predicate}\n"
        if query.rstrip() != expected.rstrip():
            raise RuntimeError(
                f"{workload.query_file} must differ from {workload.original_query_file} only by "
                + (
                    "replacing the leading SELECT count(*) with SELECT *"
                    if workload.replace_count_projection
                    else "preserving the source query"
                )
                + (
                    f" and adding the predicate {workload.unary_predicate}"
                    if workload.unary_predicate is not None
                    else ""
                )
            )
    return query


def query_without_final_semicolon(query, query_file):
    stripped = query.rstrip()
    if stripped.endswith(";"):
        stripped = stripped[:-1].rstrip()
    if ";" in stripped:
        raise RuntimeError(f"only one SQL statement is allowed in {query_file}")
    return stripped


def affinity_prefix(args):
    if args.no_affinity:
        return []
    return [args.taskset, "--cpu-list", args.cpu_list]


def duckdb_command(args, *arguments):
    return affinity_prefix(args) + [str(args.duckdb), *map(str, arguments)]


def scalar_query(args, sql):
    result = run_command(
        duckdb_command(args, "-bail", "-csv", "-noheader", "-c", sql),
        args.timeout,
        "DuckDB configuration check",
    )
    return result.stdout.strip().replace("\r", "")


def validate_environment(parser, args, workloads):
    args.duckdb = args.duckdb.resolve()
    args.database_root = args.database_root.resolve()
    if not args.duckdb.is_file() or not os.access(args.duckdb, os.X_OK):
        parser.error(f"DuckDB executable does not exist or is not executable: {args.duckdb}")
    if args.threads < 1:
        parser.error("--threads must be a positive integer")
    if args.repetitions < 1:
        parser.error("--repetitions must be a positive integer")
    if args.timeout < 1:
        parser.error("--timeout must be a positive number of seconds")

    if not args.no_affinity:
        if sys.platform != "linux":
            parser.error("CPU affinity requires Linux; use --no-affinity on other systems")
        taskset_path = shutil.which(args.taskset)
        if taskset_path is None:
            parser.error("taskset was not found; install util-linux or use --no-affinity")
        args.taskset = taskset_path
        try:
            selected_count = len(selected_cpu_ids(args.cpu_list))
        except ValueError as error:
            parser.error(str(error))
        if selected_count != args.threads:
            parser.error(
                f"--cpu-list selects {selected_count} CPUs, but --threads is {args.threads}"
            )
        available = run_command(
            [args.taskset, "--cpu-list", args.cpu_list, "nproc"],
            args.timeout,
            "CPU-affinity check",
        ).stdout.strip()
        if available != str(args.threads):
            parser.error(
                f"taskset exposes {available} CPUs, expected {args.threads}; "
                "check the host CPU IDs and cpuset limits"
            )

    expected_settings = {"yanplus_enable", "yanplus_cyclic_bags", "yanplus_semijoin_filter"}
    available_settings = set(
        filter(
            None,
            scalar_query(
                args,
                "SELECT name FROM duckdb_settings() WHERE name LIKE 'yanplus%' ORDER BY name;",
            ).splitlines(),
        )
    )
    missing_settings = expected_settings - available_settings
    if missing_settings:
        parser.error(
            f"{args.duckdb} is not a Yan+ build; missing settings: "
            + ", ".join(sorted(missing_settings))
        )

    for workload in workloads:
        database = args.database_root / workload.database_name
        if not database.is_file():
            parser.error(f"database file does not exist for {workload.name}: {database}")


def thread_setup_sql(args):
    pin_threads_count = scalar_query(
        args,
        "SELECT count(*) FROM duckdb_settings() WHERE name = 'pin_threads';",
    )
    if pin_threads_count == "1":
        return f"SET pin_threads = 'off'; SET threads = 1; SET threads = {args.threads};"
    return f"SET threads = {args.threads};"


def create_timed_query(query, query_file, destination):
    prepared = query_without_final_semicolon(query, query_file)
    destination.write_text(
        "COPY (\n" + prepared + "\n) TO '/dev/null' (FORMAT CSV);\n",
        encoding="utf-8",
    )


def run_backend(args, workload, backend, timed_query, setup_sql):
    database = args.database_root / workload.database_name
    backend_sql = (
        "SET yanplus_enable = true; "
        "SET yanplus_cyclic_bags = true; "
        f"SET yanplus_semijoin_filter = '{backend}';"
    )
    command = duckdb_command(
        args,
        "-bail",
        "-readonly",
        database,
        "-c",
        setup_sql,
        "-c",
        backend_sql,
        "-c",
        ".timer off",
        "-c",
        f".read {timed_query}",
        "-c",
        ".timer on",
    )
    for _ in range(args.repetitions):
        command.extend(("-c", f".read {timed_query}"))

    result = run_command(
        command,
        args.timeout,
        f"{workload.name}/{backend} benchmark",
    )
    combined_output = result.stdout + "\n" + result.stderr
    timings = [float(value) for value in TIMER_PATTERN.findall(combined_output)]
    if len(timings) != args.repetitions:
        raise RuntimeError(
            f"expected {args.repetitions} timer values for {workload.name}/{backend}, "
            f"found {len(timings)}\n{combined_output}"
        )
    return timings


def percentile_95(values):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * 0.95) - 1)]


def format_seconds(value):
    return f"{value:.9f}"


def samples_text(values):
    return ";".join(format_seconds(value) for value in values)


def comparison_row(args, workload, samples):
    bloom = samples["BLOOM"]
    exact_hash = samples["HASH"]
    bloom_median = statistics.median(bloom)
    hash_median = statistics.median(exact_hash)
    if hash_median < bloom_median:
        faster_backend = "HASH"
    elif bloom_median < hash_median:
        faster_backend = "BLOOM"
    else:
        faster_backend = "TIE"
    return {
        "query": workload.name,
        "query_file": workload.query_file.relative_to(REPOSITORY_ROOT).as_posix(),
        "predicate": workload.unary_predicate or "",
        "expected_selectivity_pct": (
            ""
            if workload.expected_selectivity_pct is None
            else f"{workload.expected_selectivity_pct:.1f}"
        ),
        "database": str((args.database_root / workload.database_name).resolve()),
        "threads": args.threads,
        "cpu_list": "none" if args.no_affinity else args.cpu_list,
        "repetitions": args.repetitions,
        "bloom_median_seconds": format_seconds(bloom_median),
        "bloom_p95_seconds": format_seconds(percentile_95(bloom)),
        "bloom_min_seconds": format_seconds(min(bloom)),
        "bloom_max_seconds": format_seconds(max(bloom)),
        "hash_median_seconds": format_seconds(hash_median),
        "hash_p95_seconds": format_seconds(percentile_95(exact_hash)),
        "hash_min_seconds": format_seconds(min(exact_hash)),
        "hash_max_seconds": format_seconds(max(exact_hash)),
        "hash_speedup_vs_bloom": f"{bloom_median / hash_median:.4f}",
        "bloom_speedup_vs_hash": f"{hash_median / bloom_median:.4f}",
        "faster_backend": faster_backend,
        "bloom_samples_seconds": samples_text(bloom),
        "hash_samples_seconds": samples_text(exact_hash),
    }


def write_results(rows, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.tmp")
    try:
        with temporary.open("w", encoding="utf-8", newline="") as destination:
            writer = csv.DictWriter(destination, fieldnames=CSV_FIELDS)
            writer.writeheader()
            writer.writerows(rows)
        temporary.replace(output)
    finally:
        if temporary.exists():
            temporary.unlink()


def print_summary(rows):
    print(
        "query\texpected_selectivity_pct\tbloom_median_s\thash_median_s\t"
        "bloom_speedup_vs_hash\tfaster_backend"
    )
    for row in rows:
        print(
            f"{row['query']}\t{row['expected_selectivity_pct']}\t"
            f"{row['bloom_median_seconds']}\t{row['hash_median_seconds']}\t"
            f"{row['bloom_speedup_vs_hash']}\t"
            f"{row['faster_backend']}"
        )


def main():
    parser = argparse.ArgumentParser(
        description="Compare Yan+ BLOOM and HASH semi-join filters on the LSQB Q5 sweep."
    )
    parser.add_argument(
        "--duckdb",
        type=pathlib.Path,
        default=REPOSITORY_ROOT / "build/duckdb_YanPlus/duckdb",
        help="Yan+ DuckDB CLI executable",
    )
    parser.add_argument(
        "--database-root",
        type=pathlib.Path,
        default=pathlib.Path(os.environ.get("YANPLUS_DATABASE_ROOT", REPOSITORY_ROOT)),
        help="directory containing lsqb_db",
    )
    parser.add_argument(
        "--threads",
        type=int,
        default=int(os.environ.get("YANPLUS_THREADS", DEFAULT_THREADS)),
    )
    parser.add_argument(
        "--cpu-list",
        default=os.environ.get("YANPLUS_CPU_LIST", DEFAULT_CPU_LIST),
        help="Linux taskset CPU list; its CPU count must equal --threads",
    )
    parser.add_argument(
        "--no-affinity",
        action="store_true",
        help="do not use Linux taskset (intended for development/smoke tests)",
    )
    parser.add_argument(
        "--taskset",
        default="taskset",
        help="taskset executable name or path",
    )
    parser.add_argument(
        "--repetitions",
        type=int,
        default=int(os.environ.get("YANPLUS_REPETITIONS", DEFAULT_REPETITIONS)),
        help="measured executions after one untimed warm-up",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=7200,
        help="maximum seconds for one backend's warm-up and measured executions",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=15,
        help="seed for query and backend execution order",
    )
    parser.add_argument(
        "--query",
        dest="query_selections",
        action="append",
        help="query name or comma-separated names; repeatable (default: all)",
    )
    parser.add_argument(
        "--list-queries",
        action="store_true",
        help="list query names and exit",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate and print the selected SQL without opening databases",
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=REPOSITORY_ROOT / "semijoin_comparison_results.csv",
        help="comparison CSV path",
    )
    args = parser.parse_args()

    if args.list_queries:
        for workload in WORKLOADS.values():
            print(
                f"{workload.name}\t"
                f"{workload.query_file.relative_to(REPOSITORY_ROOT).as_posix()}\t"
                f"{workload.database_name}\t"
                f"{workload.expected_selectivity_pct or ''}"
            )
        for group, members in WORKLOAD_GROUPS.items():
            print(f"group:{group}\t{','.join(members)}")
        return

    workloads = selected_workloads(parser, args.query_selections)
    queries = {workload.name: read_query(workload) for workload in workloads}
    if args.dry_run:
        for workload in workloads:
            print(f"-- {workload.name}: {workload.query_file.relative_to(REPOSITORY_ROOT)}")
            print(queries[workload.name].rstrip())
            print()
        return

    validate_environment(parser, args, workloads)
    setup_sql = thread_setup_sql(args)
    randomizer = random.Random(args.seed)
    output_order = [workload.name for workload in workloads]
    randomizer.shuffle(workloads)

    rows_by_query = {}
    with tempfile.TemporaryDirectory(prefix="yanplus-filter-comparison-") as temp_directory:
        temp_root = pathlib.Path(temp_directory)
        for workload in workloads:
            timed_query = temp_root / f"{workload.name}.sql"
            create_timed_query(queries[workload.name], workload.query_file, timed_query)
            backends = list(BACKENDS)
            randomizer.shuffle(backends)
            samples = {}
            for backend in backends:
                print(
                    f"Running {workload.name}/{backend}: threads={args.threads}, "
                    f"cpu_list={'none' if args.no_affinity else args.cpu_list}, "
                    f"warmup=1, repetitions={args.repetitions}",
                    file=sys.stderr,
                )
                samples[backend] = run_backend(
                    args, workload, backend, timed_query, setup_sql
                )
            rows_by_query[workload.name] = comparison_row(args, workload, samples)

    rows = [rows_by_query[name] for name in output_order]
    write_results(rows, args.output.resolve())
    print_summary(rows)
    print(f"Comparison CSV: {args.output.resolve()}", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
