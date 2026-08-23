#!/usr/bin/env python3
"""Run the targeted Yan+/Yannakakis correctness and performance retests."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import pathlib
import platform
import random
import re
import shutil
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass


ROOT = pathlib.Path(__file__).resolve().parent.parent
TIMER_PATTERN = re.compile(r"Run Time \(s\): real\s+([0-9]+(?:\.[0-9]+)?)")
TEMP_VIEW_PATTERN = re.compile(
    r"^(?P<prefix>(?:\s|--[^\n]*(?:\n|$)|/\*.*?\*/)*)"
    r"create\s+(?:or\s+replace\s+)?view\s+",
    re.IGNORECASE | re.DOTALL,
)

JOB_INTEGRATED_QUERIES = (
    "1b 3c 4a 5b 5c 6a 6d 7a 7c 8a 8b 8c 8d 9c 9d 10a 10c "
    "11a 11b 11d 12a 12b 12c 13a 13b 13d 14a 14b 14c 15a 15b "
    "16b 16c 16d 17b 17f 18a 18b 19a 19c 19d 20b 21a 21b 22c "
    "23a 23b 24a 24b 25a 25b 26c 27a 28a 28b 29a 29b 30a 31a "
    "31b 31c 32b 33a 33b 33c"
).split()

SETTING_NAMES = {
    "original": "Origin",
    "yannakakis_rewrite": "Yan",
    "yanplus_rewrite": "YanPlus_rewrite",
    "yanplus_integrated": "YanPlus",
}

RAW_FIELDS = [
    "suite",
    "query",
    "setting",
    "plan",
    "source_file",
    "repetition",
    "execution_order",
    "seconds",
    "status",
    "wall_seconds",
    "error",
]

SUMMARY_FIELDS = [
    "suite",
    "query",
    "setting",
    "plan",
    "runs",
    "median_seconds",
    "min_seconds",
    "max_seconds",
]


@dataclass(frozen=True)
class Plan:
    suite: str
    query: str
    label: str
    mode: str
    source: pathlib.Path
    binary_kind: str

    @property
    def key(self) -> tuple[str, str, str, str]:
        return (self.suite, self.query, self.mode, self.label)


@dataclass
class RunResult:
    status: str
    stdout: bytes
    stderr: bytes
    error: str = ""


def setting_name(mode: str) -> str:
    return SETTING_NAMES[mode]


def split_sql(sql: str) -> list[str]:
    """Split SQL without breaking quoted strings or comments."""
    statements: list[str] = []
    current: list[str] = []
    quote = None
    line_comment = False
    block_depth = 0
    index = 0
    while index < len(sql):
        char = sql[index]
        following = sql[index + 1] if index + 1 < len(sql) else ""
        current.append(char)
        if line_comment:
            if char == "\n":
                line_comment = False
            index += 1
            continue
        if block_depth:
            if char == "/" and following == "*":
                current.append(following)
                block_depth += 1
                index += 2
                continue
            if char == "*" and following == "/":
                current.append(following)
                block_depth -= 1
                index += 2
                continue
            index += 1
            continue
        if quote:
            if char == quote:
                if following == quote:
                    current.append(following)
                    index += 2
                    continue
                quote = None
            index += 1
            continue
        if char == "-" and following == "-":
            current.append(following)
            line_comment = True
            index += 2
        elif char == "/" and following == "*":
            current.append(following)
            block_depth = 1
            index += 2
        elif char in ("'", '"', "`"):
            quote = char
            index += 1
        elif char == ";":
            statement = "".join(current[:-1]).strip()
            if statement:
                statements.append(statement)
            current = []
            index += 1
        else:
            index += 1
    if quote or block_depth:
        raise ValueError("unterminated quote or block comment")
    trailing = "".join(current).strip()
    if trailing:
        statements.append(trailing)
    if not statements:
        raise ValueError("SQL file contains no statements")
    return statements


def plan_sql(plan: Plan) -> tuple[list[str], str]:
    statements = split_sql(plan.source.read_text(encoding="utf-8"))
    setup = []
    for statement in statements[:-1]:
        match = TEMP_VIEW_PATTERN.match(statement)
        if match:
            statement = (
                match.group("prefix")
                + "CREATE OR REPLACE TEMP VIEW "
                + statement[match.end() :]
            )
        setup.append(statement)
    return setup, statements[-1].rstrip().rstrip(";")


def add_plan(
    plans: dict[tuple[str, str, str, str], Plan],
    suite: str,
    query: str,
    mode: str,
    source: pathlib.Path,
    binary_kind: str,
) -> None:
    plan = Plan(suite, query, source.stem, mode, source, binary_kind)
    plans[plan.key] = plan


def add_original_pair(
    plans: dict[tuple[str, str, str, str], Plan],
    suite: str,
    query: str,
    source: pathlib.Path,
) -> None:
    add_plan(plans, suite, query, "original", source, "origin")
    add_plan(plans, suite, query, "yanplus_integrated", source, "yanplus")


def add_glob(
    plans: dict[tuple[str, str, str, str], Plan],
    suite: str,
    query: str,
    mode: str,
    pattern: str,
) -> None:
    matches = sorted(ROOT.glob(pattern))
    if not matches:
        raise ValueError(f"no files matched required pattern: {pattern}")
    for source in matches:
        add_plan(plans, suite, query, mode, source, "origin")


def add_fixed_retests(plans: dict[tuple[str, str, str, str], Plan]) -> None:
    q1_variants = (
        ("q1_800", ROOT / "graph/q1.sql", "q1", "graph_rewrite/q1_[02].sql"),
        ("q1_500", ROOT / "graph/q1_500.sql", "q1_500", "graph_rewrite/q1_500_[02].sql"),
        ("q1_1200", ROOT / "graph/q1_1200.sql", "q1_1200", "graph_rewrite/q1_1200_[02].sql"),
    )
    for query, original, stem, rewrite_pattern in q1_variants:
        add_original_pair(plans, "graph", query, original)
        add_glob(plans, "graph", query, "yanplus_rewrite", rewrite_pattern)
        add_glob(
            plans,
            "graph",
            query,
            "yannakakis_rewrite",
            f"graph_yannakakis_rewrite/{stem}_rewriteYa*.sql",
        )

    for query in ("q4", "q7"):
        add_original_pair(plans, "graph", query, ROOT / f"graph/{query}.sql")
        add_glob(plans, "graph", query, "yanplus_rewrite", f"graph_rewrite/{query}_*.sql")
        add_glob(
            plans,
            "graph",
            query,
            "yannakakis_rewrite",
            f"graph_yannakakis_rewrite/{query}_rewriteYa*.sql",
        )

    for query in ("q2", "q5"):
        add_original_pair(plans, "lsqb", query, ROOT / f"lsqb/{query}.sql")
        add_glob(plans, "lsqb", query, "yanplus_rewrite", f"lsqb_rewrite/{query}[0-9]*.sql")
        add_glob(
            plans,
            "lsqb",
            query,
            "yannakakis_rewrite",
            f"lsqb_yannakakis_rewrite/{query}_rewriteYa*.sql",
        )

    for query in ("7", "18"):
        add_original_pair(plans, "tpch", f"q{query}", ROOT / f"tpch/{query}.sql")
        add_glob(plans, "tpch", f"q{query}", "yanplus_rewrite", f"tpch_rewrite/{query}_*.sql")
        add_glob(
            plans,
            "tpch",
            f"q{query}",
            "yannakakis_rewrite",
            f"tpch_yannakakis_rewrite/{query}_rewriteYa*.sql",
        )

    dsb_queries = {
        "dsb_agg": ("013", "019", "072", "100", "101", "102"),
        "dsb_spj": ("018", "019", "025", "072", "085", "099"),
    }
    for suite, numbers in dsb_queries.items():
        for padded in numbers:
            short = str(int(padded))
            query = f"q{short}"
            add_original_pair(plans, suite, query, ROOT / suite / f"query{padded}.sql")
            add_plan(
                plans,
                suite,
                query,
                "yanplus_rewrite",
                ROOT / f"{suite}_rewrite/q{short}_r.sql",
                "origin",
            )
            add_glob(
                plans,
                suite,
                query,
                "yannakakis_rewrite",
                f"{suite}_yannakakis_rewrite/query{padded}_rewriteYa*.sql",
            )

    add_original_pair(plans, "job", "1a", ROOT / "job_agg/1a.sql")
    add_glob(
        plans,
        "job",
        "1a",
        "yannakakis_rewrite",
        "job_yannakakis_rewrite/1a_rewriteYa*.sql",
    )


def add_job_integrated_retests(plans: dict[tuple[str, str, str, str], Plan]) -> None:
    for query in JOB_INTEGRATED_QUERIES:
        add_original_pair(plans, "job", query, ROOT / f"job_agg/{query}.sql")


def add_job_yannakakis_retests(plans: dict[tuple[str, str, str, str], Plan]) -> None:
    for original in sorted((ROOT / "job_agg").glob("*.sql")):
        query = original.stem
        add_plan(plans, "job", query, "original", original, "origin")
        add_glob(
            plans,
            "job",
            query,
            "yannakakis_rewrite",
            f"job_yannakakis_rewrite/{query}_rewriteYa*.sql",
        )


def load_plans(profile: str) -> list[Plan]:
    plans: dict[tuple[str, str, str, str], Plan] = {}
    if profile in ("fixes", "all"):
        add_fixed_retests(plans)
    if profile in ("job-integrated", "all"):
        add_job_integrated_retests(plans)
    if profile in ("job-yannakakis", "all"):
        add_job_yannakakis_retests(plans)
    missing = sorted({str(plan.source) for plan in plans.values() if not plan.source.is_file()})
    if missing:
        raise ValueError("missing required query files:\n  " + "\n  ".join(missing))
    return sorted(plans.values(), key=lambda item: item.key)


def run_command(command: list[str], timeout_seconds: int) -> RunResult:
    try:
        completed = subprocess.run(command, capture_output=True, timeout=timeout_seconds)
    except subprocess.TimeoutExpired as error:
        return RunResult(
            "timeout",
            error.stdout or b"",
            error.stderr or b"",
            f"timed out after {timeout_seconds} seconds",
        )
    except OSError as error:
        return RunResult("error", b"", b"", str(error))
    if completed.returncode:
        detail = completed.stderr.decode("utf-8", errors="replace").strip()
        return RunResult("error", completed.stdout, completed.stderr, f"exit {completed.returncode}: {detail}")
    return RunResult("ok", completed.stdout, completed.stderr)


def cpu_prefix(cpu_list: str | None) -> list[str]:
    if cpu_list is None:
        return []
    if platform.system() != "Linux" or not shutil.which("taskset"):
        raise ValueError("--cpu-list requires Linux taskset; use --cpu-list none elsewhere")
    check = subprocess.run(
        ["taskset", "--cpu-list", cpu_list, "true"], capture_output=True, check=False
    )
    if check.returncode:
        raise ValueError(f"invalid or unavailable CPU list: {cpu_list}")
    return ["taskset", "--cpu-list", cpu_list]


def base_command(prefix: list[str], binary: pathlib.Path, database: pathlib.Path | None) -> list[str]:
    command = [*prefix, str(binary), "-batch", "-bail", "-csv", "-noheader"]
    if database is not None:
        command.extend(("-readonly", str(database)))
    return command


def inspect_binary(
    prefix: list[str], binary: pathlib.Path, expected_yanplus: int, timeout_seconds: int
) -> dict[str, str | bool]:
    command = base_command(prefix, binary, None)
    command.extend(
        (
            "-c",
            "SELECT version() || '|' || "
            "(SELECT count(*)::VARCHAR FROM duckdb_settings() WHERE name='yanplus_enable') || '|' || "
            "(SELECT count(*)::VARCHAR FROM duckdb_settings() WHERE name='pin_threads');",
        )
    )
    result = run_command(command, timeout_seconds)
    if result.status != "ok":
        raise ValueError(f"cannot inspect {binary}: {result.error}")
    values = result.stdout.decode("utf-8", errors="replace").strip().split("|")
    if len(values) != 3 or int(values[1]) != expected_yanplus:
        raise ValueError(f"wrong binary kind for {binary}: {result.stdout!r}")
    return {"version": values[0], "has_pin_threads": values[2] == "1"}


def database_for(suite: str, database_root: pathlib.Path) -> pathlib.Path:
    name = "dsb" if suite.startswith("dsb_") else suite
    return database_root / f"{name}_db"


def thread_statements(threads: int, has_pin_threads: bool, integrated: bool) -> list[str]:
    statements = []
    if has_pin_threads:
        statements.extend(("SET pin_threads='off'", "SET threads=1"))
    statements.append(f"SET threads={threads}")
    if integrated:
        statements.extend(("SET yanplus_enable=true", "SET yanplus_semijoin_filter='bloom'"))
    return statements


def make_command(
    plan: Plan,
    binary: pathlib.Path,
    database: pathlib.Path,
    prefix: list[str],
    threads: int,
    has_pin_threads: bool,
    warmups: int | None,
) -> list[str]:
    setup, final_query = plan_sql(plan)
    command = base_command(prefix, binary, database)
    for statement in thread_statements(threads, has_pin_threads, plan.binary_kind == "yanplus"):
        command.extend(("-c", statement))
    for statement in setup:
        command.extend(("-c", statement))
    if warmups is None:
        command.extend(("-c", final_query))
        return command
    discard = f"COPY ({final_query}) TO '/dev/null' (FORMAT CSV)"
    command.extend(("-c", ".timer off"))
    for _ in range(warmups):
        command.extend(("-c", discard))
    command.extend(("-c", ".timer on", "-c", discard, "-c", ".timer off"))
    return command


def normalized_result(contents: bytes) -> bytes:
    return b"\n".join(sorted(line.rstrip(b"\r") for line in contents.splitlines()))


def digest(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def safe_name(plan: Plan) -> str:
    raw = f"{plan.suite}-{plan.query}-{plan.mode}-{plan.label}"
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", raw)


def write_log(path: pathlib.Path, result: RunResult, seconds: float | None = None) -> None:
    with path.open("wb") as output:
        output.write(f"status={result.status}\n".encode())
        if seconds is not None:
            output.write(f"parsed_seconds={seconds:.9f}\n".encode())
        if result.error:
            output.write(f"error={result.error}\n".encode())
        output.write(b"\n[stdout]\n")
        output.write(result.stdout)
        output.write(b"\n[stderr]\n")
        output.write(result.stderr)


def validate(
    plans: list[Plan],
    binaries: dict[str, pathlib.Path],
    binary_info: dict[str, dict[str, str | bool]],
    database_root: pathlib.Path,
    prefix: list[str],
    args: argparse.Namespace,
    logs: pathlib.Path,
) -> tuple[list[dict[str, object]], set[tuple[str, str, str, str]]]:
    rows: list[dict[str, object]] = []
    invalid: set[tuple[str, str, str, str]] = set()
    groups: dict[tuple[str, str], list[Plan]] = {}
    for plan in plans:
        groups.setdefault((plan.suite, plan.query), []).append(plan)
    for group_key, group in sorted(groups.items()):
        group.sort(key=lambda plan: (plan.mode != "original", plan.mode, plan.label))
        reference: bytes | None = None
        for plan in group:
            command = make_command(
                plan,
                binaries[plan.binary_kind],
                database_for(plan.suite, database_root),
                prefix,
                args.threads,
                bool(binary_info[plan.binary_kind]["has_pin_threads"]),
                None,
            )
            result = run_command(command, args.timeout)
            write_log(logs / f"{safe_name(plan)}-validation.log", result)
            normalized = normalized_result(result.stdout) if result.status == "ok" else b""
            status = result.status
            matches = ""
            error = result.error
            if plan.mode == "original" and result.status == "ok":
                reference = normalized
                matches = "true"
            elif result.status == "ok" and reference is None:
                status = "unverified"
                error = "original result unavailable"
            elif result.status == "ok" and normalized == reference:
                matches = "true"
            elif result.status == "ok":
                status = "mismatch"
                matches = "false"
                error = "result differs from original"
                invalid.add(plan.key)
            elif result.status == "error":
                invalid.add(plan.key)
            rows.append(
                {
                    "suite": plan.suite,
                    "query": plan.query,
                    "setting": setting_name(plan.mode),
                    "plan": plan.label,
                    "source_file": plan.source.relative_to(ROOT).as_posix(),
                    "status": status,
                    "matches_original": matches,
                    "result_sha256": digest(normalized) if result.status == "ok" else "",
                    "error": error.replace("\n", " "),
                }
            )
        print(f"validated {group_key[0]}/{group_key[1]}")
    return rows, invalid


def write_csv(path: pathlib.Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def write_raw_results(output_dir: pathlib.Path, rows: list[dict[str, object]]) -> None:
    """Write the combined measurements and one raw CSV for every setting."""
    write_csv(output_dir / "raw_results.csv", RAW_FIELDS, rows)
    for setting in SETTING_NAMES.values():
        setting_rows = [row for row in rows if row["setting"] == setting]
        write_csv(output_dir / f"{setting}.csv", RAW_FIELDS, setting_rows)


def summarize(raw_rows: list[dict[str, object]], output_dir: pathlib.Path) -> None:
    successful: dict[tuple[str, str, str, str], list[tuple[int, float]]] = {}
    for row in raw_rows:
        if row["status"] == "ok":
            key = (
                str(row["suite"]),
                str(row["query"]),
                str(row["setting"]),
                str(row["plan"]),
            )
            successful.setdefault(key, []).append((int(row["repetition"]), float(row["seconds"])))
    summary_rows: list[dict[str, object]] = []
    for key, samples in sorted(successful.items()):
        values = [seconds for _, seconds in samples]
        summary_rows.append(
            {
                "suite": key[0],
                "query": key[1],
                "setting": key[2],
                "plan": key[3],
                "runs": len(values),
                "median_seconds": f"{statistics.median(values):.9f}",
                "min_seconds": f"{min(values):.9f}",
                "max_seconds": f"{max(values):.9f}",
            }
        )
    write_csv(
        output_dir / "summary.csv",
        SUMMARY_FIELDS,
        summary_rows,
    )
    for setting in SETTING_NAMES.values():
        setting_rows = [row for row in summary_rows if row["setting"] == setting]
        write_csv(output_dir / f"{setting}_summary.csv", SUMMARY_FIELDS, setting_rows)

    by_query: dict[tuple[str, str], dict[str, dict[int, float]]] = {}
    for key, samples in successful.items():
        if key[2] not in ("Origin", "YanPlus"):
            continue
        by_query.setdefault((key[0], key[1]), {})[key[2]] = dict(samples)
    comparisons: list[dict[str, object]] = []
    for key, modes in sorted(by_query.items()):
        if "Origin" not in modes or "YanPlus" not in modes:
            continue
        origin = modes["Origin"]
        yanplus = modes["YanPlus"]
        paired = sorted(set(origin) & set(yanplus))
        if not paired:
            continue
        origin_median = statistics.median(origin[rep] for rep in paired)
        yanplus_median = statistics.median(yanplus[rep] for rep in paired)
        comparisons.append(
            {
                "suite": key[0],
                "query": key[1],
                "paired_runs": len(paired),
                "Origin_median_seconds": f"{origin_median:.9f}",
                "YanPlus_median_seconds": f"{yanplus_median:.9f}",
                "Origin_over_YanPlus": f"{origin_median / yanplus_median:.6f}" if yanplus_median else "",
                "YanPlus_wins": sum(yanplus[rep] < origin[rep] for rep in paired),
            }
        )
    write_csv(
        output_dir / "integrated_comparison.csv",
        [
            "suite",
            "query",
            "paired_runs",
            "Origin_median_seconds",
            "YanPlus_median_seconds",
            "Origin_over_YanPlus",
            "YanPlus_wins",
        ],
        comparisons,
    )


def parse_args() -> argparse.Namespace:
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "--profile",
        choices=("fixes", "job-integrated", "job-yannakakis", "all"),
        default="all",
    )
    parser.add_argument(
        "--only",
        action="append",
        metavar="SUITE:QUERY",
        help="run only a selected query group; may be repeated",
    )
    parser.add_argument("--database-root", type=pathlib.Path, default=ROOT)
    parser.add_argument("--origin-bin", type=pathlib.Path, default=ROOT / "build/duckdb_origin/duckdb")
    parser.add_argument("--yanplus-bin", type=pathlib.Path, default=ROOT / "build/duckdb_YanPlus/duckdb")
    parser.add_argument("--threads", type=int, default=64)
    parser.add_argument("--cpu-list", default="0-31,36-67", help="Linux taskset list or 'none'")
    parser.add_argument("--repetitions", type=int, default=7)
    parser.add_argument("--warmups", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=7200, help="seconds per process")
    parser.add_argument("--seed", type=int, default=20260823)
    parser.add_argument("--skip-validation", action="store_true")
    parser.add_argument("--dry-run", action="store_true", help="list selected work without needing databases")
    parser.add_argument("--output-dir", type=pathlib.Path, default=ROOT / "required_retest_results" / timestamp)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.threads < 1 or args.repetitions < 1 or args.warmups < 0 or args.timeout < 1:
        print("error: threads/repetitions/timeout must be positive and warmups nonnegative", file=sys.stderr)
        return 2
    try:
        plans = load_plans(args.profile)
        if args.only:
            requested = set()
            for value in args.only:
                if ":" not in value:
                    raise ValueError(f"--only must use SUITE:QUERY, got {value!r}")
                requested.add(tuple(value.split(":", 1)))
            available = {(plan.suite, plan.query) for plan in plans}
            unknown = sorted(requested - available)
            if unknown:
                raise ValueError(
                    "--only selections are not in this profile: "
                    + ", ".join(f"{suite}:{query}" for suite, query in unknown)
                )
            plans = [plan for plan in plans if (plan.suite, plan.query) in requested]
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    groups = {(plan.suite, plan.query) for plan in plans}
    print(f"profile={args.profile}: {len(groups)} query groups, {len(plans)} plans")
    if args.dry_run:
        for plan in plans:
            print(
                f"{plan.suite}\t{plan.query}\t{setting_name(plan.mode)}\t"
                f"{plan.source.relative_to(ROOT)}"
            )
        return 0

    args.database_root = args.database_root.resolve()
    binaries = {"origin": args.origin_bin.resolve(), "yanplus": args.yanplus_bin.resolve()}
    for kind, binary in binaries.items():
        if not binary.is_file() or not os.access(binary, os.X_OK):
            print(f"error: {kind} binary missing or not executable: {binary}", file=sys.stderr)
            return 2
    databases = {plan.suite: database_for(plan.suite, args.database_root) for plan in plans}
    for suite, database in sorted(databases.items()):
        if not database.is_file():
            print(f"error: {suite} database missing: {database}", file=sys.stderr)
            return 2
    cpu_list = None if args.cpu_list.casefold() == "none" else args.cpu_list
    try:
        prefix = cpu_prefix(cpu_list)
        binary_info = {
            "origin": inspect_binary(prefix, binaries["origin"], 0, args.timeout),
            "yanplus": inspect_binary(prefix, binaries["yanplus"], 1, args.timeout),
        }
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    output_dir = args.output_dir.resolve()
    if output_dir.exists() and any(output_dir.iterdir()):
        print(f"error: output directory is not empty: {output_dir}", file=sys.stderr)
        return 2
    output_dir.mkdir(parents=True, exist_ok=True)
    logs = output_dir / "logs"
    logs.mkdir()
    metadata = {
        "started_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "profile": args.profile,
        "query_groups": len(groups),
        "plans": len(plans),
        "origin_binary": str(binaries["origin"]),
        "yanplus_binary": str(binaries["yanplus"]),
        "binary_info": binary_info,
        "database_root": str(args.database_root),
        "threads": args.threads,
        "cpu_list": cpu_list,
        "repetitions": args.repetitions,
        "warmups": args.warmups,
        "timeout_seconds": args.timeout,
        "seed": args.seed,
        "validation_enabled": not args.skip_validation,
        "settings": list(SETTING_NAMES.values()),
        "platform": platform.platform(),
        "logical_cpu_count": os.cpu_count(),
        "timing_scope": "final query only; temporary views are logical and their execution is included",
        "design": "fresh process; randomized query blocks and randomized mode order; median is primary",
    }
    (output_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    invalid: set[tuple[str, str, str, str]] = set()
    if not args.skip_validation:
        validation_rows, invalid = validate(
            plans, binaries, binary_info, args.database_root, prefix, args, logs
        )
        write_csv(
            output_dir / "validation.csv",
            [
                "suite",
                "query",
                "setting",
                "plan",
                "source_file",
                "status",
                "matches_original",
                "result_sha256",
                "error",
            ],
            validation_rows,
        )

    by_query: dict[tuple[str, str], list[Plan]] = {}
    for plan in plans:
        by_query.setdefault((plan.suite, plan.query), []).append(plan)
    rng = random.Random(args.seed)
    raw_rows: list[dict[str, object]] = []
    write_raw_results(output_dir, raw_rows)
    execution_order = 0
    failed: set[tuple[str, str, str, str]] = set()
    for repetition in range(1, args.repetitions + 1):
        query_blocks = list(by_query.items())
        rng.shuffle(query_blocks)
        print(f"timing repetition {repetition}/{args.repetitions}")
        for _, block in query_blocks:
            block = list(block)
            rng.shuffle(block)
            for plan in block:
                execution_order += 1
                if plan.key in invalid or plan.key in failed:
                    continue
                command = make_command(
                    plan,
                    binaries[plan.binary_kind],
                    database_for(plan.suite, args.database_root),
                    prefix,
                    args.threads,
                    bool(binary_info[plan.binary_kind]["has_pin_threads"]),
                    args.warmups,
                )
                started = time.monotonic()
                result = run_command(command, args.timeout)
                wall = time.monotonic() - started
                combined = result.stdout.decode("utf-8", errors="replace") + "\n" + result.stderr.decode(
                    "utf-8", errors="replace"
                )
                matches = TIMER_PATTERN.findall(combined)
                seconds = float(matches[-1]) if result.status == "ok" and matches else None
                status = result.status
                error = result.error
                if status == "ok" and seconds is None:
                    status = "timer_parse_error"
                    error = "DuckDB timer output not found"
                if status != "ok":
                    failed.add(plan.key)
                write_log(logs / f"{safe_name(plan)}-r{repetition}.log", result, seconds)
                raw_rows.append(
                    {
                        "suite": plan.suite,
                        "query": plan.query,
                        "setting": setting_name(plan.mode),
                        "plan": plan.label,
                        "source_file": plan.source.relative_to(ROOT).as_posix(),
                        "repetition": repetition,
                        "execution_order": execution_order,
                        "seconds": f"{seconds:.9f}" if seconds is not None else "",
                        "status": status,
                        "wall_seconds": f"{wall:.3f}",
                        "error": error.replace("\n", " "),
                    }
                )
                print(
                    f"  {plan.suite}/{plan.query} {setting_name(plan.mode)}/{plan.label}: "
                    + (f"{seconds:.6f}s" if seconds is not None else status)
                )
                write_raw_results(output_dir, raw_rows)
    summarize(raw_rows, output_dir)
    print(f"results: {output_dir}")
    return 1 if invalid or failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
