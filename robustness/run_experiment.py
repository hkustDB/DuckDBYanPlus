#!/usr/bin/env python3
"""Validate and benchmark every commit-pinned robustness rewrite."""

from __future__ import annotations

import argparse
import csv
import datetime
import hashlib
import json
import os
import pathlib
import platform
import random
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass


ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = ROOT.parent
RAW_FIELDS = (
    "suite",
    "query",
    "plan",
    "plan_kind",
    "source_file",
    "repetition",
    "execution_order",
    "seconds",
    "status",
    "error",
)
VALIDATION_FIELDS = (
    "suite",
    "query",
    "plan",
    "plan_kind",
    "source_file",
    "status",
    "matches_original",
    "result_sha256",
    "error",
)
TIMER_PATTERN = re.compile(r"Run Time \(s\): real\s+([0-9]+(?:\.[0-9]+)?)")
TEMP_VIEW_PATTERN = re.compile(
    r"^(?P<prefix>(?:\s|--[^\n]*(?:\n|$)|/\*.*?\*/)*)"
    r"create\s+(?:or\s+replace\s+)?view\s+",
    re.IGNORECASE | re.DOTALL,
)


@dataclass(frozen=True)
class Plan:
    suite: str
    query: str
    name: str
    kind: str
    source_file: pathlib.Path
    setup: tuple[str, ...]
    final_query: str

    @property
    def key(self) -> tuple[str, str, str]:
        return (self.suite, self.query, self.name)


@dataclass
class CommandResult:
    status: str
    stdout: bytes
    stderr: bytes
    error: str


def split_sql(sql: str) -> list[str]:
    """Split SQL statements while respecting quotes and SQL comments."""
    statements = []
    current = []
    quote = None
    line_comment = False
    block_comment_depth = 0
    index = 0
    while index < len(sql):
        character = sql[index]
        next_character = sql[index + 1] if index + 1 < len(sql) else ""
        current.append(character)

        if line_comment:
            if character == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment_depth:
            if character == "/" and next_character == "*":
                current.append(next_character)
                block_comment_depth += 1
                index += 2
                continue
            if character == "*" and next_character == "/":
                current.append(next_character)
                block_comment_depth -= 1
                index += 2
                continue
            index += 1
            continue
        if quote:
            if character == quote:
                if next_character == quote:
                    current.append(next_character)
                    index += 2
                    continue
                quote = None
            index += 1
            continue

        if character == "-" and next_character == "-":
            current.append(next_character)
            line_comment = True
            index += 2
        elif character == "/" and next_character == "*":
            current.append(next_character)
            block_comment_depth = 1
            index += 2
        elif character in ("'", '"', "`"):
            quote = character
            index += 1
        elif character == ";":
            statement = "".join(current[:-1]).strip()
            if statement:
                statements.append(statement)
            current = []
            index += 1
        else:
            index += 1

    if quote or block_comment_depth:
        raise ValueError("unterminated quote or block comment")
    statement = "".join(current).strip()
    if statement:
        statements.append(statement)
    if not statements:
        raise ValueError("SQL file contains no statements")
    return statements


def prepare_plan(suite: str, query: str, kind: str, source_file: pathlib.Path) -> Plan:
    statements = split_sql(source_file.read_text(encoding="utf-8"))
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
    name = "query" if kind == "original" else source_file.stem
    return Plan(suite, query, name, kind, source_file, tuple(setup), statements[-1])


def sha256(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def read_manifest() -> list[dict[str, str]]:
    manifest_path = ROOT / "manifest.tsv"
    with manifest_path.open(newline="", encoding="utf-8") as source:
        rows = list(csv.DictReader(source, delimiter="\t"))
    required = {
        "kind",
        "suite",
        "query",
        "local_file",
        "upstream_commit",
        "upstream_path",
        "upstream_sha256",
        "local_sha256",
        "adaptation",
    }
    if not rows or not required.issubset(rows[0]):
        raise ValueError("manifest.tsv is empty or has an invalid header")
    return rows


def load_plans() -> list[Plan]:
    rows = read_manifest()
    plans = []
    originals: dict[tuple[str, str], int] = {}
    rewrites: dict[tuple[str, str], list[int]] = {}
    for row in rows:
        source_file = ROOT / row["local_file"]
        if not source_file.is_file():
            raise ValueError(f"missing manifest file: {source_file}")
        if sha256(source_file.read_bytes()) != row["local_sha256"]:
            raise ValueError(f"SHA-256 mismatch: {source_file}")
        plan = prepare_plan(row["suite"], row["query"], row["kind"], source_file)
        plans.append(plan)
        query_key = (plan.suite, plan.query)
        if plan.kind == "original":
            originals[query_key] = originals.get(query_key, 0) + 1
        else:
            match = re.fullmatch(r"rewrite([1-9][0-9]*)", plan.name)
            if not match:
                raise ValueError(f"invalid local rewrite name: {plan.name}")
            rewrites.setdefault(query_key, []).append(int(match.group(1)))

    if any(count != 1 for count in originals.values()):
        raise ValueError("every sampled query must have exactly one query.sql")
    if set(originals) != set(rewrites):
        raise ValueError("every sampled query must have original and rewrite plans")
    for query_key, numbers in rewrites.items():
        if sorted(numbers) != list(range(1, len(numbers) + 1)):
            raise ValueError(f"rewrites are not one-based and contiguous for {query_key}")
    return plans


def select_plans(
    plans: list[Plan], query_labels: list[str], rewrites_only: bool
) -> list[Plan]:
    available = {f"{plan.suite}-{plan.query}" for plan in plans}
    requested = set(query_labels)
    unknown = sorted(requested - available)
    if unknown:
        raise ValueError(
            "unknown --only-query value(s): "
            + ", ".join(unknown)
            + "; available values: "
            + ", ".join(sorted(available))
        )
    selected = [
        plan
        for plan in plans
        if (not requested or f"{plan.suite}-{plan.query}" in requested)
        and (not rewrites_only or plan.kind == "rewrite")
    ]
    if not selected:
        raise ValueError("plan selection is empty")
    return selected


def command_prefix(cpu_list: str | None) -> list[str]:
    if not cpu_list:
        return []
    if platform.system() != "Linux":
        raise ValueError("--cpu-list requires Linux taskset")
    taskset = shutil.which("taskset")
    if not taskset:
        raise ValueError("--cpu-list requires taskset")
    check = subprocess.run(
        [taskset, "--cpu-list", cpu_list, "true"], capture_output=True, check=False
    )
    if check.returncode:
        raise ValueError(f"invalid or unavailable CPU list: {cpu_list}")
    return [taskset, "--cpu-list", cpu_list]


def run_command(command: list[str], timeout_seconds: int) -> CommandResult:
    try:
        completed = subprocess.run(command, capture_output=True, timeout=timeout_seconds)
    except subprocess.TimeoutExpired as error:
        return CommandResult(
            "timeout",
            error.stdout or b"",
            error.stderr or b"",
            f"timed out after {timeout_seconds} seconds",
        )
    except OSError as error:
        return CommandResult("error", b"", b"", str(error))
    if completed.returncode:
        detail = completed.stderr.decode("utf-8", errors="replace").strip()
        return CommandResult(
            "error",
            completed.stdout,
            completed.stderr,
            f"exit {completed.returncode}: {detail}",
        )
    return CommandResult("ok", completed.stdout, completed.stderr, "")


def base_command(
    executable: pathlib.Path,
    database: pathlib.Path | None,
    prefix: list[str],
    readonly: bool = True,
) -> list[str]:
    command = [*prefix, str(executable), "-batch", "-bail", "-csv", "-noheader"]
    if readonly:
        command.append("-readonly")
    if database is not None:
        command.append(str(database))
    return command


def append_sql(command: list[str], statement: str) -> None:
    command.extend(("-c", statement))


def plan_command(
    plan: Plan,
    executable: pathlib.Path,
    database: pathlib.Path,
    prefix: list[str],
    threads: int,
    warmups: int | None,
) -> list[str]:
    command = base_command(executable, database, prefix)
    append_sql(command, f"SET threads = {threads};")
    for statement in plan.setup:
        append_sql(command, statement)
    if warmups is None:
        append_sql(command, plan.final_query)
        return command

    final_query = plan.final_query.rstrip()
    if final_query.endswith(";"):
        final_query = final_query[:-1]
    discard_query = (
        "COPY (\n" + final_query + "\n) TO '/dev/null' (FORMAT CSV);"
    )
    append_sql(command, ".timer off")
    for _ in range(warmups):
        append_sql(command, discard_query)
    append_sql(command, ".timer on")
    append_sql(command, discard_query)
    append_sql(command, ".timer off")
    return command


def database_for(plan: Plan, databases: dict[str, pathlib.Path]) -> pathlib.Path:
    try:
        return databases[plan.suite]
    except KeyError as error:
        raise ValueError(f"no database configured for suite {plan.suite}") from error


def safe_log_name(plan: Plan, repetition: int | None = None) -> str:
    base = f"{plan.suite}-{plan.query}-{plan.name}"
    return f"{base}-validation.log" if repetition is None else f"{base}-r{repetition}.log"


def write_log(path: pathlib.Path, result: CommandResult, elapsed: float | None = None) -> None:
    with path.open("wb") as destination:
        destination.write(f"status={result.status}\n".encode())
        if elapsed is not None:
            destination.write(f"parsed_seconds={elapsed:.9f}\n".encode())
        if result.error:
            destination.write(f"error={result.error}\n".encode())
        destination.write(b"\n[stdout]\n")
        destination.write(result.stdout)
        destination.write(b"\n[stderr]\n")
        destination.write(result.stderr)


def validate_plans(
    plans: list[Plan],
    executable: pathlib.Path,
    databases: dict[str, pathlib.Path],
    prefix: list[str],
    threads: int,
    timeout_seconds: int,
    logs: pathlib.Path,
) -> tuple[list[dict[str, str]], set[tuple[str, str, str]]]:
    rows = []
    timing_eligible = set()
    by_query: dict[tuple[str, str], list[Plan]] = {}
    for plan in plans:
        by_query.setdefault((plan.suite, plan.query), []).append(plan)

    for query_key, query_plans in sorted(by_query.items()):
        query_plans.sort(key=lambda plan: (plan.kind != "original", plan.name))
        original_result: bytes | None = None
        for plan in query_plans:
            command = plan_command(
                plan,
                executable,
                database_for(plan, databases),
                prefix,
                threads,
                warmups=None,
            )
            result = run_command(command, timeout_seconds)
            write_log(logs / safe_log_name(plan), result)
            normalized = result.stdout.rstrip(b"\r\n") if result.status == "ok" else b""
            matches = False
            status = result.status
            error = result.error
            if plan.kind == "original" and status == "ok":
                original_result = normalized
                matches = True
                timing_eligible.add(plan.key)
            elif plan.kind == "rewrite" and status == "ok":
                if original_result is None:
                    status = "unverified"
                    error = "original result unavailable; rewrite will still be timed"
                    timing_eligible.add(plan.key)
                elif normalized == original_result:
                    matches = True
                    timing_eligible.add(plan.key)
                else:
                    status = "mismatch"
                    error = "result differs from query.sql"
            rows.append(
                {
                    "suite": plan.suite,
                    "query": plan.query,
                    "plan": plan.name,
                    "plan_kind": plan.kind,
                    "source_file": plan.source_file.relative_to(ROOT).as_posix(),
                    "status": status,
                    "matches_original": "true" if matches else "false",
                    "result_sha256": sha256(normalized) if result.status == "ok" else "",
                    "error": error.replace("\n", " "),
                }
            )
    return rows, timing_eligible


def write_metadata(
    output_directory: pathlib.Path,
    args: argparse.Namespace,
    executable: pathlib.Path,
    databases: dict[str, pathlib.Path],
    version: str,
    plans: list[Plan],
) -> None:
    metadata = {
        "started_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "duckdb": str(executable),
        "duckdb_version": version,
        "databases": {suite: str(path) for suite, path in databases.items()},
        "threads": args.threads,
        "cpu_list": args.cpu_list,
        "repetitions": args.repetitions,
        "warmups_per_repetition": args.warmups,
        "random_seed": args.seed,
        "timeout_seconds": args.timeout,
        "selected_queries": sorted(
            {f"{plan.suite}-{plan.query}" for plan in plans}
        ),
        "rewrites_only": args.rewrites_only,
        "platform": platform.platform(),
        "logical_cpu_count": os.cpu_count(),
        "plan_count_including_originals": len(plans),
        "selected_plan_count": len(plans),
        "manifest_sha256": sha256((ROOT / "manifest.tsv").read_bytes()),
        "timing_scope": "final SELECT; setup creates logical temporary views and is untimed",
        "execution_design": "one fresh DuckDB process per plan per repetition; globally shuffled blocks",
    }
    (output_directory / "metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def csv_writer(path: pathlib.Path, fields: tuple[str, ...]):
    destination = path.open("w", newline="", encoding="utf-8")
    writer = csv.DictWriter(destination, fieldnames=fields)
    writer.writeheader()
    destination.flush()
    return destination, writer


def check_origin_binary(
    executable: pathlib.Path, prefix: list[str], timeout_seconds: int
) -> str:
    command = base_command(executable, None, prefix, readonly=False)
    append_sql(
        command,
        "SELECT version() || '|' || (SELECT count(*)::VARCHAR FROM duckdb_settings() "
        "WHERE name = 'yanplus_enable');",
    )
    result = run_command(command, timeout_seconds)
    if result.status != "ok":
        raise ValueError(f"cannot inspect DuckDB executable: {result.error}")
    output = result.stdout.decode("utf-8", errors="replace").strip()
    if not output.endswith("|0"):
        raise ValueError(
            "benchmark requires an original DuckDB build without the yanplus_enable setting; "
            f"inspection returned {output!r}"
        )
    return output.rsplit("|", 1)[0]


def parse_args() -> argparse.Namespace:
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--duckdb",
        type=pathlib.Path,
        default=REPOSITORY_ROOT / "build/duckdb_origin/duckdb",
    )
    parser.add_argument(
        "--lsqb-database", type=pathlib.Path, default=REPOSITORY_ROOT / "lsqb_db"
    )
    parser.add_argument(
        "--job-database", type=pathlib.Path, default=REPOSITORY_ROOT / "job_db"
    )
    parser.add_argument("--threads", type=int, default=64)
    parser.add_argument(
        "--cpu-list",
        default="0-31,36-67",
        help="Linux taskset CPU list; pass 'none' to disable CPU pinning",
    )
    parser.add_argument("--repetitions", type=int, default=10)
    parser.add_argument("--warmups", type=int, default=1)
    parser.add_argument("--seed", type=int, default=20260822)
    parser.add_argument("--timeout", type=int, default=600, help="per-process seconds")
    parser.add_argument(
        "--only-query",
        action="append",
        default=[],
        metavar="SUITE-QUERY",
        help="run only a query label such as lsqb-q9; may be repeated",
    )
    parser.add_argument(
        "--rewrites-only",
        action="store_true",
        help="skip every query.sql original and run only rewrite plans",
    )
    parser.add_argument(
        "--output-dir", type=pathlib.Path, default=ROOT / "results" / timestamp
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.cpu_list.casefold() == "none":
        args.cpu_list = None
    if args.threads < 1 or args.repetitions < 1 or args.warmups < 0 or args.timeout < 1:
        print("error: threads, repetitions, and timeout must be positive; warmups cannot be negative", file=sys.stderr)
        return 2
    executable = args.duckdb.resolve()
    databases = {
        "lsqb": args.lsqb_database.resolve(),
        "job": args.job_database.resolve(),
    }
    if not executable.is_file() or not os.access(executable, os.X_OK):
        print(f"error: DuckDB executable is missing or not executable: {executable}", file=sys.stderr)
        return 2
    try:
        plans = select_plans(load_plans(), args.only_query, args.rewrites_only)
    except (OSError, ValueError, UnicodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    for suite in sorted({plan.suite for plan in plans}):
        database = databases[suite]
        if not database.is_file():
            print(f"error: {suite} database does not exist: {database}", file=sys.stderr)
            return 2

    output_directory = args.output_dir.resolve()
    if output_directory.exists() and any(output_directory.iterdir()):
        print(f"error: output directory is not empty: {output_directory}", file=sys.stderr)
        return 2
    output_directory.mkdir(parents=True, exist_ok=True)
    logs = output_directory / "logs"
    logs.mkdir()

    try:
        prefix = command_prefix(args.cpu_list)
        version = check_origin_binary(executable, prefix, args.timeout)
    except (OSError, ValueError, UnicodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    write_metadata(output_directory, args, executable, databases, version, plans)

    validation_label = (
        "Checking rewrite execution"
        if args.rewrites_only
        else "Validating exact results"
    )
    print(f"{validation_label} for {len(plans)} plans...")
    validation_rows, timing_eligible = validate_plans(
        plans,
        executable,
        databases,
        prefix,
        args.threads,
        args.timeout,
        logs,
    )
    validation_file, validation_writer = csv_writer(
        output_directory / "validation.csv", VALIDATION_FIELDS
    )
    validation_writer.writerows(validation_rows)
    validation_file.close()

    timed_plans = [plan for plan in plans if plan.key in timing_eligible]
    exact_validation_count = sum(
        row["status"] == "ok" and row["matches_original"] == "true"
        for row in validation_rows
    )
    unverified_rewrites = sum(
        row["plan_kind"] == "rewrite" and row["status"] == "unverified"
        for row in validation_rows
    )
    validation_failures = sum(
        row["status"] in {"timeout", "error", "mismatch"}
        for row in validation_rows
    )
    print(
        f"Eligible for timing: {len(timed_plans)}/{len(plans)} plans; "
        f"exactly validated={exact_validation_count}; "
        f"unverified rewrites={unverified_rewrites}; failures={validation_failures}."
    )

    raw_file, raw_writer = csv_writer(output_directory / "raw_results.csv", RAW_FIELDS)
    failed_timing_plans: set[tuple[str, str, str]] = set()
    execution_order = 0
    rng = random.Random(args.seed)
    for repetition in range(1, args.repetitions + 1):
        block = list(timed_plans)
        rng.shuffle(block)
        print(f"Timing randomized block {repetition}/{args.repetitions} ({len(block)} plans)...")
        for plan in block:
            if plan.key in failed_timing_plans:
                continue
            execution_order += 1
            command = plan_command(
                plan,
                executable,
                database_for(plan, databases),
                prefix,
                args.threads,
                args.warmups,
            )
            started = time.monotonic()
            result = run_command(command, args.timeout)
            wall_seconds = time.monotonic() - started
            combined = result.stdout.decode("utf-8", errors="replace") + "\n" + result.stderr.decode(
                "utf-8", errors="replace"
            )
            matches = TIMER_PATTERN.findall(combined)
            elapsed = float(matches[-1]) if result.status == "ok" and matches else None
            status = result.status
            error = result.error
            if result.status == "ok" and elapsed is None:
                status = "timer_parse_error"
                error = "DuckDB timer output was not found"
            if status != "ok":
                failed_timing_plans.add(plan.key)
            write_log(logs / safe_log_name(plan, repetition), result, elapsed)
            raw_writer.writerow(
                {
                    "suite": plan.suite,
                    "query": plan.query,
                    "plan": plan.name,
                    "plan_kind": plan.kind,
                    "source_file": plan.source_file.relative_to(ROOT).as_posix(),
                    "repetition": repetition,
                    "execution_order": execution_order,
                    "seconds": f"{elapsed:.9f}" if elapsed is not None else "",
                    "status": status,
                    "error": error.replace("\n", " "),
                }
            )
            raw_file.flush()
            label = f"{plan.suite}-{plan.query}/{plan.name}"
            if elapsed is None:
                print(f"  {label}: {status} (wall {wall_seconds:.2f}s)")
            else:
                print(f"  {label}: {elapsed:.6f}s")
    raw_file.close()

    summary_command = [
        sys.executable,
        str(ROOT / "summarize.py"),
        str(output_directory / "raw_results.csv"),
        str(output_directory / "validation.csv"),
        "--output-dir",
        str(output_directory),
    ]
    summary = subprocess.run(summary_command, check=False)
    print(f"Results: {output_directory}")
    unexpected_unverified = 0 if args.rewrites_only else unverified_rewrites
    if validation_failures or unexpected_unverified or failed_timing_plans or summary.returncode:
        print(
            f"Experiment incomplete: validation_failures={validation_failures}, "
            f"unverified_rewrites={unverified_rewrites}, "
            f"timing_failures={len(failed_timing_plans)}.",
            file=sys.stderr,
        )
        return 1
    if unverified_rewrites:
        print(
            "Rewrite-only run complete; semantic comparison was intentionally skipped."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
