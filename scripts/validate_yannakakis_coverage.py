#!/usr/bin/env python3
"""Validate deterministic Yannakakis rewrite and manifest coverage.

This validator intentionally performs filesystem and manifest checks only.  SQL
binding needs suite-specific schemas (and, for LSQB, parameter substitution), so
it belongs in the execution/semantic validators rather than this coverage gate.
"""

import argparse
import csv
import pathlib
import re
import sys


REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST_NAME = "yannakakis_rewrite_manifest.tsv"
SUITES = {
    "graph": ("graph", "graph_yannakakis_rewrite"),
    "lsqb": ("lsqb", "lsqb_yannakakis_rewrite"),
    "tpch": ("tpch", "tpch_yannakakis_rewrite"),
    "job": ("job_agg", "job_yannakakis_rewrite"),
}


def remove_sql_comments(sql):
    """Remove SQL comments while preserving quoted strings and identifiers."""
    output = []
    index = 0
    quote = None
    line_comment = False
    block_comment_depth = 0
    while index < len(sql):
        if line_comment:
            if sql[index] == "\n":
                line_comment = False
                output.append("\n")
            index += 1
            continue
        if block_comment_depth:
            if sql.startswith("/*", index):
                block_comment_depth += 1
                index += 2
            elif sql.startswith("*/", index):
                block_comment_depth -= 1
                index += 2
            else:
                index += 1
            continue
        if quote:
            output.append(sql[index])
            if sql[index] == quote:
                if index + 1 < len(sql) and sql[index + 1] == quote:
                    output.append(sql[index + 1])
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
            block_comment_depth = 1
            index += 2
            continue
        if sql[index] in ("'", '"'):
            quote = sql[index]
        output.append(sql[index])
        index += 1
    return "".join(output)


def contains_sql(path, errors, context):
    try:
        sql = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        errors.append(f"{context}: cannot read UTF-8 SQL: {error}")
        return False
    # A comment marker or a file containing only statement separators is not a
    # runnable rewrite, even though its byte size is nonzero.
    if not re.search(r"[^\s;]", remove_sql_comments(sql)):
        errors.append(f"{context}: contains no executable SQL")
        return False
    return True


def relative_display(path, root):
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


def read_manifest(path, errors):
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as error:
        errors.append(f"manifest {path}: cannot read UTF-8 TSV: {error}")
        return [], set()

    data_lines = [line for line in lines if line.strip() and not line.startswith("#")]
    if not data_lines:
        errors.append(f"manifest {path}: missing header and rows")
        return [], set()

    reader = csv.DictReader(data_lines, delimiter="\t")
    required = {"suite", "local_original", "local_artifact", "status"}
    fields = set(reader.fieldnames or [])
    missing_fields = sorted(required - fields)
    if missing_fields:
        errors.append(
            f"manifest {path}: missing required column(s): {', '.join(missing_fields)}"
        )
        return [], fields

    rows = []
    for row_number, row in enumerate(reader, start=2):
        if None in row:
            errors.append(
                f"manifest {path}, data row {row_number}: has more fields than the header"
            )
        rows.append((row_number, row))
    if not rows:
        errors.append(f"manifest {path}: has no artifact rows")
    return rows, fields


def validate(root, manifest_path):
    errors = []
    originals_by_suite = {}
    artifacts_by_suite = {}
    artifact_has_sql = {}

    for suite, (original_name, rewrite_name) in SUITES.items():
        original_dir = root / original_name
        rewrite_dir = root / rewrite_name
        if not original_dir.is_dir():
            errors.append(f"suite {suite}: original directory is missing: {original_dir}")
            originals_by_suite[suite] = {}
        else:
            originals = sorted(original_dir.glob("*.sql"))
            originals_by_suite[suite] = {path.stem: path for path in originals}
            if not originals:
                errors.append(f"suite {suite}: no original *.sql queries in {original_dir}")

        if not rewrite_dir.is_dir():
            errors.append(f"suite {suite}: rewrite directory is missing: {rewrite_dir}")
            artifacts_by_suite[suite] = {}
            continue

        artifacts = sorted(rewrite_dir.glob("*.sql"))
        artifacts_by_suite[suite] = {path.resolve(): path for path in artifacts}
        if not artifacts:
            errors.append(f"suite {suite}: no rewrite *.sql artifacts in {rewrite_dir}")
        for artifact in artifacts:
            display = relative_display(artifact, root)
            artifact_has_sql[artifact.resolve()] = contains_sql(
                artifact, errors, f"artifact {display}"
            )

        for stem, original in originals_by_suite.get(suite, {}).items():
            prefix = f"{stem}_rewriteYa"
            candidates = [
                artifact
                for artifact in artifacts
                if artifact.name.startswith(prefix) and artifact.suffix == ".sql"
            ]
            nonempty = [
                artifact
                for artifact in candidates
                if artifact_has_sql.get(artifact.resolve(), False)
            ]
            if not nonempty:
                display = relative_display(original, root)
                if candidates:
                    details = ", ".join(
                        relative_display(path, root) for path in candidates
                    )
                    errors.append(
                        f"suite {suite}: original {display} has no nonempty rewrite "
                        f"(candidate(s): {details})"
                    )
                else:
                    errors.append(
                        f"suite {suite}: original {display} has no corresponding "
                        f"{prefix}*.sql artifact"
                    )

    rows, _ = read_manifest(manifest_path, errors)
    manifested_artifacts = set()
    manifested_originals = {suite: set() for suite in SUITES}
    for row_number, row in rows:
        context = f"manifest data row {row_number}"
        suite = (row.get("suite") or "").strip()
        local_original = (row.get("local_original") or "").strip()
        local_artifact = (row.get("local_artifact") or "").strip()
        status = (row.get("status") or "").strip()

        if suite not in SUITES:
            errors.append(f"{context}: unknown suite {suite!r}")
            continue
        if not status:
            errors.append(f"{context}: empty status")
        elif "blank" in status.casefold():
            errors.append(f"{context}: blank status is not allowed: {status!r}")

        expected_originals = originals_by_suite.get(suite, {})
        expected_original_paths = {
            relative_display(path, root): stem for stem, path in expected_originals.items()
        }
        original_stem = None
        if not local_original:
            errors.append(f"{context}: empty local_original")
        elif local_original not in expected_original_paths:
            errors.append(
                f"{context}: local_original is not a {suite} original: {local_original}"
            )
        else:
            original_stem = expected_original_paths[local_original]
            manifested_originals[suite].add(original_stem)

        if not local_artifact:
            errors.append(f"{context}: empty local_artifact")
            continue
        artifact_value = pathlib.PurePosixPath(local_artifact)
        if artifact_value.is_absolute() or ".." in artifact_value.parts:
            errors.append(
                f"{context}: local_artifact must be a repository-relative path: "
                f"{local_artifact}"
            )
            continue
        artifact = (root / pathlib.Path(*artifact_value.parts)).resolve()
        expected_artifacts = artifacts_by_suite.get(suite, {})
        if artifact not in expected_artifacts:
            expected_dir = SUITES[suite][1]
            errors.append(
                f"{context}: artifact is missing or outside {expected_dir}: "
                f"{local_artifact}"
            )
            continue
        if artifact in manifested_artifacts:
            errors.append(f"{context}: duplicate manifest artifact: {local_artifact}")
        manifested_artifacts.add(artifact)
        if original_stem and not artifact.name.startswith(
            f"{original_stem}_rewriteYa"
        ):
            errors.append(
                f"{context}: artifact {local_artifact} does not correspond to "
                f"original {local_original}"
            )
        if not artifact_has_sql.get(artifact, False):
            errors.append(
                f"{context}: manifest references an empty SQL artifact: "
                f"{local_artifact}"
            )

    for suite, originals in originals_by_suite.items():
        for stem, original in originals.items():
            if stem not in manifested_originals.get(suite, set()):
                errors.append(
                    f"manifest: missing row for original "
                    f"{relative_display(original, root)}"
                )

    all_artifacts = set()
    for artifacts in artifacts_by_suite.values():
        all_artifacts.update(artifacts)
    for artifact in sorted(all_artifacts - manifested_artifacts):
        errors.append(
            f"manifest: unmanaged rewrite artifact {relative_display(artifact, root)}"
        )

    counts = {
        "suites": len(SUITES),
        "originals": sum(len(items) for items in originals_by_suite.values()),
        "artifacts": len(all_artifacts),
        "manifest_rows": len(rows),
    }
    return errors, counts


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Check that every Graph, LSQB, TPC-H, and JOB query has a nonempty "
            "Yannakakis rewrite and that the manifest is complete and blank-free."
        )
    )
    parser.add_argument(
        "--root",
        type=pathlib.Path,
        default=REPOSITORY_ROOT,
        help="repository root (default: inferred from this script)",
    )
    parser.add_argument(
        "--manifest",
        type=pathlib.Path,
        help=f"manifest path (default: ROOT/{MANIFEST_NAME})",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    if not root.is_dir():
        parser.error(f"repository root does not exist: {root}")
    manifest = args.manifest.resolve() if args.manifest else root / MANIFEST_NAME

    errors, counts = validate(root, manifest)
    if errors:
        print(
            f"Yannakakis coverage validation failed with {len(errors)} error(s):",
            file=sys.stderr,
        )
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(
        "Validated complete Yannakakis rewrite coverage: "
        f"{counts['originals']} originals, {counts['artifacts']} nonempty artifacts, "
        f"{counts['manifest_rows']} manifest rows across {counts['suites']} suites."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
