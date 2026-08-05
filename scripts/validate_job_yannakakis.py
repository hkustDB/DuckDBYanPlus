#!/usr/bin/env python3
"""Validate JOB Yannakakis SUM rewrites with DuckDB's own SQL semantics."""

import argparse
import concurrent.futures
import pathlib
import re
import subprocess
import sys
import tempfile


REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[1]


def split_statements(sql):
    statements = []
    start = 0
    index = 0
    quote = None
    line_comment = False
    block_comment = False
    while index < len(sql):
        if line_comment:
            if sql[index] == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment:
            if sql.startswith("*/", index):
                block_comment = False
                index += 2
            else:
                index += 1
            continue
        if quote:
            if sql[index] == quote:
                if index + 1 < len(sql) and sql[index + 1] == quote:
                    index += 2
                    continue
                quote = None
            index += 1
            continue
        if sql.startswith("--", index):
            line_comment = True
            index += 2
            continue
        if sql.startswith("/*", index):
            block_comment = True
            index += 2
            continue
        if sql[index] in ("'", '"'):
            quote = sql[index]
        elif sql[index] == ";":
            statement = sql[start:index].strip()
            if statement:
                statements.append(statement)
            start = index + 1
        index += 1
    statement = sql[start:].strip()
    if statement:
        statements.append(statement)
    return statements


def rewrite_parts(path):
    statements = split_statements(path.read_text(encoding="utf-8"))
    if not statements:
        raise RuntimeError("empty SQL artifact")
    setup = ";\n".join(statements[:-1])
    if setup:
        setup += ";\n"
    return setup, statements[-1]


def run_duckdb(binary, database, sql):
    result = subprocess.run(
        [str(binary), "-readonly", "-batch", "-bail", "-csv", "-noheader", str(database)],
        input=sql,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(detail)
    return result.stdout.strip()


def validate_artifact(
    binary, database, artifact, original_dir, compare_results, threads
):
    base_name = artifact.name.split("_rewriteYa", 1)[0]
    original = original_dir / f"{base_name}.sql"
    if not original.is_file():
        raise RuntimeError(f"missing paired original: {original}")
    sql = artifact.read_text(encoding="utf-8")
    if not sql.strip():
        raise RuntimeError("blank SQL artifact")
    if re.search(r"\bMIN\s*\(", sql, re.IGNORECASE):
        raise RuntimeError("JOB SUM rewrite contains MIN")
    if not re.search(r"\bSUM\s*\(\s*1\s*\)", sql, re.IGNORECASE):
        raise RuntimeError("JOB SUM rewrite does not contain SUM(1)")

    setup, final_query = rewrite_parts(artifact)
    if compare_results:
        expected_query = original.read_text(encoding="utf-8").strip().rstrip(";")
        validation_sql = (
            f"SET threads = {threads};\n"
            + setup
            + "CREATE OR REPLACE TEMP TABLE __ya_expected AS "
            + expected_query
            + ";\nCREATE OR REPLACE TEMP TABLE __ya_actual AS "
            + final_query
            + ";\nSELECT count(*) FROM ((SELECT * FROM __ya_expected EXCEPT ALL "
            "SELECT * FROM __ya_actual) UNION ALL (SELECT * FROM __ya_actual "
            "EXCEPT ALL SELECT * FROM __ya_expected)) AS differences;\n"
        )
        output = run_duckdb(binary, database, validation_sql)
        last_line = output.splitlines()[-1] if output else ""
        if last_line != "0":
            raise RuntimeError(f"result mismatch ({last_line or 'no difference count'})")
    else:
        run_duckdb(
            binary,
            database,
            f"SET threads = {threads};\n" + setup + "EXPLAIN " + final_query + ";\n",
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--duckdb",
        type=pathlib.Path,
        default=REPOSITORY_ROOT / "build" / "duckdb_origin" / "duckdb",
        help="DuckDB CLI used for binding or result validation",
    )
    parser.add_argument(
        "--database",
        type=pathlib.Path,
        help="real job_db; when set, compare results with EXCEPT ALL",
    )
    parser.add_argument(
        "--query-dir",
        type=pathlib.Path,
        default=REPOSITORY_ROOT / "job_yannakakis_rewrite",
    )
    parser.add_argument(
        "--original-dir",
        type=pathlib.Path,
        default=REPOSITORY_ROOT / "job_agg",
    )
    parser.add_argument(
        "--schema",
        type=pathlib.Path,
        default=REPOSITORY_ROOT / "benchmark" / "imdb_plan_cost" / "init" / "schema.sql",
        help="empty JOB schema used when --database is omitted",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        help="parallel validators (default: 4 for binding, 1 for result comparison)",
    )
    parser.add_argument("--threads", type=int, default=1, help="DuckDB threads per validator")
    args = parser.parse_args()

    binary = args.duckdb.resolve()
    query_dir = args.query_dir.resolve()
    original_dir = args.original_dir.resolve()
    if not binary.is_file():
        parser.error(f"DuckDB CLI does not exist: {binary}")
    if not query_dir.is_dir() or not original_dir.is_dir():
        parser.error("query and original directories must exist")
    workers = args.jobs if args.jobs is not None else (1 if args.database else 4)
    if workers < 1:
        parser.error("--jobs must be positive")
    if args.threads < 1:
        parser.error("--threads must be positive")

    artifacts = sorted(query_dir.glob("*.sql"))
    originals = sorted(original_dir.glob("*.sql"))
    covered = {path.name.split("_rewriteYa", 1)[0] for path in artifacts if path.stat().st_size}
    missing = sorted(path.stem for path in originals if path.stem not in covered)
    if missing:
        parser.error("missing nonempty JOB rewrites: " + ", ".join(missing))

    temporary = None
    compare_results = args.database is not None
    if compare_results:
        database = args.database.resolve()
        if not database.is_file():
            parser.error(f"JOB database does not exist: {database}")
    else:
        schema = args.schema.resolve()
        if not schema.is_file():
            parser.error(f"JOB schema does not exist: {schema}")
        temporary = tempfile.TemporaryDirectory(prefix="duckdb-ya-validate-")
        database = pathlib.Path(temporary.name) / "empty_job.duckdb"
        initialize = subprocess.run(
            [str(binary), "-batch", "-bail", str(database)],
            input=schema.read_text(encoding="utf-8"),
            capture_output=True,
            text=True,
        )
        if initialize.returncode:
            detail = initialize.stderr.strip() or initialize.stdout.strip()
            parser.error(f"could not create empty JOB schema: {detail}")

    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {
            executor.submit(
                validate_artifact,
                binary,
                database,
                artifact,
                original_dir,
                compare_results,
                args.threads,
            ): artifact
            for artifact in artifacts
        }
        for future in concurrent.futures.as_completed(futures):
            artifact = futures[future]
            try:
                future.result()
            except Exception as error:  # report every invalid artifact
                failures.append((artifact, str(error)))

    if temporary:
        temporary.cleanup()
    if failures:
        for artifact, detail in sorted(failures):
            print(f"{artifact}: {detail}", file=sys.stderr)
        return 1
    mode = "result-equivalent" if compare_results else "DuckDB-bound"
    print(
        f"Validated {len(artifacts)} {mode} JOB Yannakakis SUM artifacts "
        f"with complete {len(originals)}/{len(originals)} query coverage."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
