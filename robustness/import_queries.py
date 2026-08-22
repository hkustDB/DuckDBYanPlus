#!/usr/bin/env python3
"""Import the commit-pinned robustness queries from Yannakakis-Plus."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parent
SOURCE_REPOSITORY = "https://github.com/hkustDB/Yannakakis-Plus"
LSQB_COMMIT = "3e39c2c04ba240d69bcf4bf5c30cb32c95589288"
JOB_COMMIT = "d73438b37e87de20b81b85478bc9c6082ef5b3bd"
QUERY_SPECS = (
    ("lsqb", "q1", LSQB_COMMIT, "query/lsqb/q1"),
    ("lsqb", "q9", LSQB_COMMIT, "query/lsqb/q9"),
    ("job", "2d", JOB_COMMIT, "query/job/2d"),
    ("job", "15d", JOB_COMMIT, "query/job/15d"),
    ("job", "17a", JOB_COMMIT, "query/job/17a"),
    ("job", "22d", JOB_COMMIT, "query/job/22d"),
)
REWRITE_PATTERN = re.compile(r"^rewrite([0-9]+)\.sql$")
MANIFEST_HEADER = (
    "kind\tsuite\tquery\tlocal_file\tupstream_commit\tupstream_path\t"
    "upstream_sha256\tlocal_sha256\tadaptation\n"
)


def git(source: pathlib.Path, *arguments: str) -> bytes:
    command = ["git", "-C", str(source), *arguments]
    try:
        return subprocess.run(command, check=True, capture_output=True).stdout
    except subprocess.CalledProcessError as error:
        detail = error.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"{' '.join(command)} failed: {detail}") from error


def tree_names(source: pathlib.Path, commit: str, directory: str) -> list[str]:
    output = git(source, "ls-tree", "--name-only", f"{commit}:{directory}")
    return output.decode("utf-8").splitlines()


def blob(source: pathlib.Path, commit: str, upstream_path: str) -> bytes:
    return git(source, "show", f"{commit}:{upstream_path}")


def sha256(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def adapt_for_duckdb(
    contents: bytes, suite: str, query: str, kind: str
) -> tuple[bytes, str]:
    if (suite, query, kind) == ("lsqb", "q1", "original"):
        marker = b"`Comment`"
        if contents.count(marker) != 3:
            raise RuntimeError("unexpected LSQB q1 identifier quoting at the pinned commit")
        return contents.replace(marker, b"Comment"), "duckdb_identifier_quote"
    return contents, "copied"


def manifest_row(
    kind: str,
    suite: str,
    query: str,
    local_path: pathlib.Path,
    commit: str,
    upstream_path: str,
    upstream: bytes,
    local: bytes,
    adaptation: str,
) -> str:
    return (
        f"{kind}\t{suite}\t{query}\t{local_path.relative_to(ROOT).as_posix()}\t"
        f"{commit}\t{upstream_path}\t{sha256(upstream)}\t{sha256(local)}\t{adaptation}\n"
    )


def expected_import(source: pathlib.Path) -> tuple[dict[pathlib.Path, bytes], str]:
    files: dict[pathlib.Path, bytes] = {}
    manifest_rows: list[str] = []

    for suite, query, commit, upstream_directory in QUERY_SPECS:
        local_directory = ROOT / f"{suite}-{query}"
        original_path = f"{upstream_directory}/query.sql"
        upstream_original = blob(source, commit, original_path)
        original, adaptation = adapt_for_duckdb(
            upstream_original, suite, query, "original"
        )
        local_original = local_directory / "query.sql"
        files[local_original] = original
        manifest_rows.append(
            manifest_row(
                "original",
                suite,
                query,
                local_original,
                commit,
                original_path,
                upstream_original,
                original,
                adaptation,
            )
        )

        rewrites = []
        for name in tree_names(source, commit, upstream_directory):
            match = REWRITE_PATTERN.fullmatch(name)
            if match:
                rewrites.append((int(match.group(1)), name))
        rewrites.sort()
        if not rewrites:
            raise RuntimeError(f"no generic rewriteN.sql files in {commit}:{upstream_directory}")

        # The selected source directories sometimes start at rewrite0 and often
        # have gaps. Normalize every complete set to the requested one-based
        # rewrite1.sql, rewrite2.sql, ... convention; the manifest preserves the
        # original identifier.
        for local_number, (_, upstream_name) in enumerate(rewrites, start=1):
            upstream_path = f"{upstream_directory}/{upstream_name}"
            upstream_contents = blob(source, commit, upstream_path)
            contents, adaptation = adapt_for_duckdb(
                upstream_contents, suite, query, "rewrite"
            )
            local_path = local_directory / f"rewrite{local_number}.sql"
            files[local_path] = contents
            manifest_rows.append(
                manifest_row(
                    "rewrite",
                    suite,
                    query,
                    local_path,
                    commit,
                    upstream_path,
                    upstream_contents,
                    contents,
                    adaptation,
                )
            )

    return files, MANIFEST_HEADER + "".join(manifest_rows)


def check_import(files: dict[pathlib.Path, bytes], manifest: str) -> list[str]:
    errors = []
    for local_path, expected in files.items():
        if not local_path.is_file():
            errors.append(f"missing {local_path.relative_to(ROOT)}")
        elif local_path.read_bytes() != expected:
            errors.append(f"content mismatch: {local_path.relative_to(ROOT)}")

    expected_paths = {path.resolve() for path in files}
    for suite, query, _, _ in QUERY_SPECS:
        local_directory = ROOT / f"{suite}-{query}"
        if local_directory.is_dir():
            for local_path in local_directory.glob("*.sql"):
                if local_path.resolve() not in expected_paths:
                    errors.append(f"unexpected SQL file: {local_path.relative_to(ROOT)}")

    manifest_path = ROOT / "manifest.tsv"
    if not manifest_path.is_file():
        errors.append("missing manifest.tsv")
    elif manifest_path.read_text(encoding="utf-8") != manifest:
        errors.append("content mismatch: manifest.tsv")
    return errors


def write_import(files: dict[pathlib.Path, bytes], manifest: str) -> None:
    for local_path, contents in files.items():
        local_path.parent.mkdir(parents=True, exist_ok=True)
        local_path.write_bytes(contents)
    (ROOT / "manifest.tsv").write_text(manifest, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path, help="checkout of hkustDB/Yannakakis-Plus")
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed import without changing files",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source = args.source.resolve()
    if not (source / ".git").exists():
        print(f"error: not a Git checkout: {source}", file=sys.stderr)
        return 2

    try:
        files, manifest = expected_import(source)
    except (RuntimeError, UnicodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    if args.check:
        errors = check_import(files, manifest)
        if errors:
            for error in errors:
                print(f"error: {error}", file=sys.stderr)
            return 1
        print(f"Verified {len(files)} SQL files against {SOURCE_REPOSITORY}.")
        return 0

    write_import(files, manifest)
    rewrite_count = sum(path.name.startswith("rewrite") for path in files)
    print(f"Imported {rewrite_count} rewrites and {len(QUERY_SPECS)} originals.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
