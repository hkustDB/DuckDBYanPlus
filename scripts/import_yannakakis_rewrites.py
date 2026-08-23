#!/usr/bin/env python3
"""Import, adapt, and simulate complete DuckDB Yannakakis-style baselines."""

import argparse
import hashlib
import pathlib
import re
import subprocess
import sys


REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[1]
QUORION_URL = "https://github.com/hkustDB/Quorion"
QUORION_COMMIT = "3e48996acc152fc1b19c780ab5c0c9f5f6885e33"
MANIFEST_NAME = "yannakakis_rewrite_manifest.tsv"
SUITES = {
    "graph": ("graph", "graph_duckdb", "graph_yannakakis_rewrite"),
    "lsqb": ("lsqb", "lsqb_duckdb", "lsqb_yannakakis_rewrite"),
    "tpch": ("tpch", "tpch_duckdb", "tpch_yannakakis_rewrite"),
    # JOB is regenerated from the local DuckDB SUM(1) workload. Quorion's
    # rewriteYa files define the source variant set, but their MIN aggregation
    # pipelines cannot be changed mechanically because most payloads are text.
    "job": ("job_agg", "job_duckdb", "job_yannakakis_rewrite"),
}


IDENTIFIER = r"[A-Za-z_][A-Za-z0-9_$]*"


def sql_tokens(sql):
    """Tokenize conservatively while ignoring formatting and comments."""
    tokens = []
    index = 0
    while index < len(sql):
        if sql[index].isspace():
            index += 1
            continue
        if sql.startswith("--", index):
            newline = sql.find("\n", index + 2)
            index = len(sql) if newline < 0 else newline + 1
            continue
        if sql.startswith("/*", index):
            terminator = sql.find("*/", index + 2)
            if terminator < 0:
                raise ValueError("unterminated SQL block comment")
            index = terminator + 2
            continue

        character = sql[index]
        if character in ("'", '"'):
            quote = character
            end = index + 1
            while end < len(sql):
                if sql[end] == quote:
                    if end + 1 < len(sql) and sql[end + 1] == quote:
                        end += 2
                        continue
                    end += 1
                    break
                end += 1
            else:
                raise ValueError("unterminated SQL quoted value")
            # Quoted contents are case-sensitive and must match exactly.
            tokens.append(sql[index:end])
            index = end
            continue

        token = re.match(
            r"[A-Za-z_][A-Za-z0-9_$]*|"
            r"(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?|"
            r"<=|>=|<>|!=|::|.",
            sql[index:],
            re.DOTALL,
        )
        if not token:
            raise ValueError("could not tokenize SQL")
        value = token.group(0)
        tokens.append(value.lower())
        index += len(value)

    while tokens and tokens[-1] == ";":
        tokens.pop()
    return tuple(tokens)


def normalized_digest(path):
    normalized = "\x1f".join(sql_tokens(path.read_text(encoding="utf-8")))
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def find_top_level_keyword(sql, keyword, start=0):
    """Find a SQL keyword outside quotes and parentheses."""
    keyword_lower = keyword.lower()
    depth = 0
    quote = None
    index = start
    while index < len(sql):
        character = sql[index]
        if quote:
            if character == quote:
                if index + 1 < len(sql) and sql[index + 1] == quote:
                    index += 2
                    continue
                quote = None
            index += 1
            continue
        if character in ("'", '"'):
            quote = character
            index += 1
            continue
        if sql.startswith("--", index):
            newline = sql.find("\n", index + 2)
            index = len(sql) if newline < 0 else newline + 1
            continue
        if sql.startswith("/*", index):
            terminator = sql.find("*/", index + 2)
            if terminator < 0:
                raise ValueError("unterminated SQL block comment")
            index = terminator + 2
            continue
        if character == "(":
            depth += 1
            index += 1
            continue
        if character == ")":
            depth -= 1
            index += 1
            continue
        if depth == 0 and sql[index : index + len(keyword)].lower() == keyword_lower:
            before = sql[index - 1] if index else " "
            after_index = index + len(keyword)
            after = sql[after_index] if after_index < len(sql) else " "
            if not (before.isalnum() or before in "_$") and not (
                after.isalnum() or after in "_$"
            ):
                return index
        index += 1
    return -1


def split_top_level_commas(sql):
    """Split a SQL list on commas outside quotes and parentheses."""
    parts = []
    start = 0
    depth = 0
    quote = None
    index = 0
    while index < len(sql):
        character = sql[index]
        if quote:
            if character == quote:
                if index + 1 < len(sql) and sql[index + 1] == quote:
                    index += 2
                    continue
                quote = None
        elif character in ("'", '"'):
            quote = character
        elif character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
        elif character == "," and depth == 0:
            parts.append(sql[start:index].strip())
            start = index + 1
        index += 1
    parts.append(sql[start:].strip())
    return [part for part in parts if part]


def split_top_level_and(sql):
    """Split a predicate conjunction, keeping the AND in BETWEEN intact."""
    parts = []
    start = 0
    depth = 0
    quote = None
    between_pending = False
    index = 0
    while index < len(sql):
        character = sql[index]
        if quote:
            if character == quote:
                if index + 1 < len(sql) and sql[index + 1] == quote:
                    index += 2
                    continue
                quote = None
            index += 1
            continue
        if character in ("'", '"'):
            quote = character
            index += 1
            continue
        if character == "(":
            depth += 1
            index += 1
            continue
        if character == ")":
            depth -= 1
            index += 1
            continue
        if character.isalpha() or character == "_":
            end = index + 1
            while end < len(sql) and (sql[end].isalnum() or sql[end] in "_$"):
                end += 1
            word = sql[index:end].lower()
            if depth == 0 and word == "between":
                between_pending = True
            elif depth == 0 and word == "and":
                if between_pending:
                    between_pending = False
                else:
                    parts.append(sql[start:index].strip())
                    start = end
            index = end
            continue
        index += 1
    parts.append(sql[start:].strip())
    return [part for part in parts if part]


def parse_job_sum_query(path):
    """Parse the deliberately simple SQL-92 shape used by job_agg."""
    sql = path.read_text(encoding="utf-8").strip()
    while sql.endswith(";"):
        sql = sql[:-1].rstrip()

    select_at = find_top_level_keyword(sql, "select")
    from_at = find_top_level_keyword(sql, "from", select_at + len("select"))
    where_at = find_top_level_keyword(sql, "where", from_at + len("from"))
    group_at = find_top_level_keyword(sql, "group by", where_at + len("where"))
    if select_at != 0 or min(from_at, where_at, group_at) < 0:
        raise RuntimeError(f"unsupported JOB SUM query shape: {path}")

    select_clause = sql[select_at + len("select") : from_at].strip()
    from_clause = sql[from_at + len("from") : where_at].strip()
    where_clause = sql[where_at + len("where") : group_at].strip()
    group_clause = sql[group_at + len("group by") :].strip()

    relations = []
    relation_pattern = re.compile(
        rf"^({IDENTIFIER}(?:\.{IDENTIFIER})?)\s+(?:AS\s+)?({IDENTIFIER})$",
        re.IGNORECASE,
    )
    for relation in split_top_level_commas(from_clause):
        match = relation_pattern.match(relation)
        if not match:
            raise RuntimeError(f"unsupported JOB FROM item in {path}: {relation}")
        relations.append((match.group(1), match.group(2)))

    aliases = [alias for _, alias in relations]
    alias_lookup = {alias.lower(): alias for alias in aliases}
    if len(alias_lookup) != len(aliases):
        raise RuntimeError(f"duplicate JOB relation alias in {path}")

    selections = {alias: [] for alias in aliases}
    joins = {}
    residual = []
    conditions = split_top_level_and(where_clause)
    for condition in conditions:
        references = {
            alias_lookup[reference.lower()]
            for reference in re.findall(rf"\b({IDENTIFIER})\s*\.", condition)
            if reference.lower() in alias_lookup
        }
        if len(references) == 1:
            selections[next(iter(references))].append(condition)
        elif len(references) == 2:
            edge = tuple(sorted(references, key=str.lower))
            joins.setdefault(edge, []).append(condition)
        else:
            residual.append(condition)

    if residual:
        predicates = ", ".join(residual)
        raise RuntimeError(f"unsupported JOB predicate in {path}: {predicates}")
    if not re.search(r"\bSUM\s*\(\s*1\s*\)", select_clause, re.IGNORECASE):
        raise RuntimeError(f"JOB Yannakakis baseline requires SUM(1): {path}")
    if re.search(r"\bMIN\s*\(", sql, re.IGNORECASE):
        raise RuntimeError(f"JOB SUM input unexpectedly contains MIN: {path}")

    return {
        "select": select_clause,
        "where": where_clause,
        "group": group_clause,
        "relations": relations,
        "selections": selections,
        "joins": joins,
    }


def safe_identifier(value):
    return re.sub(r"[^A-Za-z0-9_]", "_", value)


def spanning_forest(aliases, joins, seed):
    adjacency = {alias: set() for alias in aliases}
    for left, right in joins:
        adjacency[left].add(right)
        adjacency[right].add(left)

    preferred = sorted(aliases, key=str.lower)
    if preferred:
        rotation = seed % len(preferred)
        preferred = preferred[rotation:] + preferred[:rotation]
    parent = {}
    children = {alias: [] for alias in aliases}
    roots = []
    for root in preferred:
        if root in parent:
            continue
        roots.append(root)
        parent[root] = None
        queue = [root]
        while queue:
            current = queue.pop(0)
            neighbors = sorted(adjacency[current], key=str.lower)
            if neighbors:
                rotation = (seed + len(parent)) % len(neighbors)
                neighbors = neighbors[rotation:] + neighbors[:rotation]
            for neighbor in neighbors:
                if neighbor in parent:
                    continue
                parent[neighbor] = current
                children[current].append(neighbor)
                queue.append(neighbor)
    return roots, parent, children


def indent_predicates(predicates, prefix):
    return ("\n" + prefix + "AND ").join(f"({predicate})" for predicate in predicates)


def qualified_column_refs(expression, alias_lookup):
    """Return ordered, de-duplicated alias/column references from an expression."""
    result = []
    seen = set()
    pattern = re.compile(rf"\b({IDENTIFIER})\s*\.\s*({IDENTIFIER})\b")
    for match in pattern.finditer(expression):
        alias = alias_lookup.get(match.group(1).lower())
        if not alias:
            continue
        reference = (alias, match.group(2))
        key = (alias.lower(), match.group(2).lower())
        if key not in seen:
            result.append(reference)
            seen.add(key)
    return result


def rewrite_qualified_columns(expression, alias_lookup, source_for_alias):
    """Rewrite a.col to <stage>.a__col for a round-3 annotated view."""

    pattern = re.compile(rf"\b({IDENTIFIER})\s*\.\s*({IDENTIFIER})\b")

    def replace(match):
        alias = alias_lookup.get(match.group(1).lower())
        if not alias or alias not in source_for_alias:
            return match.group(0)
        return (
            source_for_alias[alias]
            + "."
            + safe_identifier(alias)
            + "__"
            + safe_identifier(match.group(2))
        )

    return pattern.sub(replace, expression)


def generate_job_yannakakis(local_original, rewrite_name, upstream_rewrite):
    """Generate a bag-correct DuckDB Yannakakis-style reducer for JOB SUM(1)."""
    parsed = parse_job_sum_query(local_original)
    variant_match = re.search(r"rewriteYa(\d*)", rewrite_name, re.IGNORECASE)
    seed = int(variant_match.group(1) or 0) if variant_match else 0
    aliases = [alias for _, alias in parsed["relations"]]
    roots, parent, children = spanning_forest(aliases, parsed["joins"], seed)
    if len(roots) != 1:
        raise RuntimeError(
            f"JOB join graph must be connected for Yannakakis reduction: {local_original}"
        )
    variant = safe_identifier(pathlib.Path(rewrite_name).stem)
    prefix = f"ya_{safe_identifier(local_original.stem)}_{variant}"
    statements = [
        "-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from "
        f"{local_original.relative_to(REPOSITORY_ROOT).as_posix()}.",
        "-- Source variant: "
        + (
            upstream_rewrite
            if upstream_rewrite
            else "locally generated fallback (Quorion has no rewriteYa for JOB 1a)"
        ),
    ]

    base_views = {}
    for table, alias in parsed["relations"]:
        view = f"{prefix}_base_{safe_identifier(alias)}"
        base_views[alias] = view
        statement = (
            f"CREATE OR REPLACE TEMP VIEW {view} AS\n"
            f"SELECT {alias}.*\nFROM {table} AS {alias}"
        )
        if parsed["selections"][alias]:
            statement += "\nWHERE " + indent_predicates(parsed["selections"][alias], "  ")
        statements.append(statement + ";")

    up_views = {}

    def build_up(alias):
        for child in children[alias]:
            build_up(child)
        view = f"{prefix}_up_{safe_identifier(alias)}"
        up_views[alias] = view
        statement = (
            f"CREATE OR REPLACE TEMP VIEW {view} AS\n"
            f"SELECT {alias}.*\nFROM {base_views[alias]} AS {alias}"
        )
        filters = []
        for child in children[alias]:
            edge = tuple(sorted((alias, child), key=str.lower))
            predicates = parsed["joins"].get(edge)
            if not predicates:
                raise RuntimeError(
                    f"missing join predicate for JOB tree edge {alias}-{child}: {local_original}"
                )
            filters.append(
                f"EXISTS (SELECT 1 FROM {up_views[child]} AS {child} WHERE "
                + " AND ".join(f"({predicate})" for predicate in predicates)
                + ")"
            )
        if filters:
            statement += "\nWHERE " + "\n  AND ".join(filters)
        statements.append(statement + ";")

    for root in roots:
        build_up(root)

    down_views = {}
    for root in roots:
        view = f"{prefix}_down_{safe_identifier(root)}"
        down_views[root] = view
        statements.append(
            f"CREATE OR REPLACE TEMP VIEW {view} AS\n"
            f"SELECT {root}.*\nFROM {up_views[root]} AS {root};"
        )
        queue = [root]
        while queue:
            current = queue.pop(0)
            for child in children[current]:
                edge = tuple(sorted((current, child), key=str.lower))
                predicates = parsed["joins"][edge]
                child_view = f"{prefix}_down_{safe_identifier(child)}"
                down_views[child] = child_view
                statements.append(
                    f"CREATE OR REPLACE TEMP VIEW {child_view} AS\n"
                    f"SELECT {child}.*\nFROM {up_views[child]} AS {child}\n"
                    f"WHERE EXISTS (SELECT 1 FROM {down_views[current]} AS {current} WHERE "
                    + " AND ".join(f"({predicate})" for predicate in predicates)
                    + ");"
                )
                queue.append(child)

    # Round 3: aggregate and project after every tree join.  Keeping the full
    # reduced join until the root defeats the purpose of the Yannakakis+
    # rewrite on JOB: many queries have only two or three result columns but
    # a very large cyclic join result.  The messages below retain only result
    # columns and columns that cross the current subtree boundary.  Non-tree
    # predicates are evaluated at the first stage containing both endpoints,
    # so the rewrite remains exact for the cyclic JOB alias graphs.
    alias_lookup = {alias.lower(): alias for alias in aliases}
    group_expressions = split_top_level_commas(parsed["group"])
    group_refs = []
    for expression in group_expressions:
        refs = qualified_column_refs(expression, alias_lookup)
        if len(refs) != 1 or expression.strip().lower() != (
            refs[0][0] + "." + refs[0][1]
        ).lower():
            raise RuntimeError(
                f"JOB round-3 aggregation requires direct GROUP BY columns: "
                f"{local_original}: {expression}"
            )
        if refs[0] not in group_refs:
            group_refs.append(refs[0])

    condition_entries = []
    referenced_columns = {alias: [] for alias in aliases}
    for edge, predicates in parsed["joins"].items():
        for predicate in predicates:
            refs = qualified_column_refs(predicate, alias_lookup)
            if len({alias for alias, _ in refs}) != 2:
                raise RuntimeError(
                    f"unsupported JOB round-3 join predicate in {local_original}: {predicate}"
                )
            condition_entries.append((set(edge), predicate, refs))
            for alias, column in refs:
                if column not in referenced_columns[alias]:
                    referenced_columns[alias].append(column)
    for alias, column in group_refs:
        if column not in referenced_columns[alias]:
            referenced_columns[alias].append(column)

    def column_name(alias, column):
        return safe_identifier(alias) + "__" + safe_identifier(column)

    def required_columns(scope):
        required = []
        for reference in group_refs:
            if reference[0] in scope and reference not in required:
                required.append(reference)
        for _, _, refs in condition_entries:
            referenced_aliases = {alias for alias, _ in refs}
            if referenced_aliases & scope and referenced_aliases - scope:
                for reference in refs:
                    if reference[0] in scope and reference not in required:
                        required.append(reference)
        return required

    round3_base = {}
    for _, alias in parsed["relations"]:
        view = f"{prefix}_r3_base_{safe_identifier(alias)}"
        round3_base[alias] = view
        columns = referenced_columns[alias]
        select_columns = [
            f"{alias}.{column} AS {column_name(alias, column)}" for column in columns
        ]
        select_columns.append("CAST(COUNT(*) AS HUGEINT) AS annot")
        statement = (
            f"CREATE OR REPLACE TEMP VIEW {view} AS\nSELECT "
            + ",\n       ".join(select_columns)
            + f"\nFROM {down_views[alias]} AS {alias}"
        )
        if columns:
            statement += "\nGROUP BY " + ", ".join(
                f"{alias}.{column}" for column in columns
            )
        statements.append(statement + ";")

    round3_counter = 0

    def build_round3(alias):
        nonlocal round3_counter
        current_view = round3_base[alias]
        current_scope = {alias}
        for child in children[alias]:
            child_view, child_scope = build_round3(child)
            crossing = [
                predicate
                for edge, predicate, _ in condition_entries
                if edge & current_scope and edge & child_scope
            ]
            if not crossing:
                raise RuntimeError(
                    f"missing JOB round-3 predicate between subtrees in {local_original}"
                )
            combined_scope = current_scope | child_scope
            output_refs = required_columns(combined_scope)
            source_for_alias = {
                member: ("round3_left" if member in current_scope else "round3_right")
                for member in combined_scope
            }
            select_columns = [
                source_for_alias[owner]
                + "."
                + column_name(owner, column)
                + " AS "
                + column_name(owner, column)
                for owner, column in output_refs
            ]
            select_columns.append(
                "SUM(round3_left.annot * round3_right.annot) AS annot"
            )
            join_predicates = [
                rewrite_qualified_columns(
                    predicate, alias_lookup, source_for_alias
                )
                for predicate in crossing
            ]
            round3_counter += 1
            next_view = f"{prefix}_r3_join_{round3_counter}"
            statement = (
                f"CREATE OR REPLACE TEMP VIEW {next_view} AS\nSELECT "
                + ",\n       ".join(select_columns)
                + f"\nFROM {current_view} AS round3_left\n"
                + f"JOIN {child_view} AS round3_right\n  ON "
                + "\n AND ".join(f"({predicate})" for predicate in join_predicates)
            )
            if output_refs:
                statement += "\nGROUP BY " + ", ".join(
                    source_for_alias[owner] + "." + column_name(owner, column)
                    for owner, column in output_refs
                )
            statements.append(statement + ";")
            current_view = next_view
            current_scope = combined_scope
        return current_view, current_scope

    final_view, final_scope = build_round3(roots[0])
    if final_scope != set(aliases):
        raise RuntimeError(f"incomplete JOB round-3 tree for {local_original}")
    result_columns = [
        "round3_result."
        + column_name(alias, column)
        + " AS "
        + safe_identifier(column)
        for alias, column in group_refs
    ]
    result_columns.append("round3_result.annot AS record_count")
    statements.append(
        "SELECT "
        + ",\n       ".join(result_columns)
        + f"\nFROM {final_view} AS round3_result;"
    )
    result = ("\n\n".join(statements) + "\n").encode("utf-8")
    if re.search(rb"\bMIN\s*\(", result, re.IGNORECASE):
        raise RuntimeError(f"generated JOB rewrite still contains MIN: {local_original}")
    return result


def parse_graph_query(path):
    """Parse the comma-join shape used by the local Graph workload."""
    sql = path.read_text(encoding="utf-8").strip()
    while sql.endswith(";"):
        sql = sql[:-1].rstrip()

    select_at = find_top_level_keyword(sql, "select")
    from_at = find_top_level_keyword(sql, "from", select_at + len("select"))
    where_at = find_top_level_keyword(sql, "where", from_at + len("from"))
    if select_at != 0 or min(from_at, where_at) < 0:
        raise RuntimeError(f"unsupported Graph query shape: {path}")

    select_clause = sql[select_at + len("select") : from_at].strip()
    from_clause = sql[from_at + len("from") : where_at].strip()
    where_clause = sql[where_at + len("where") :].strip()
    relation_pattern = re.compile(
        rf"^({IDENTIFIER}(?:\.{IDENTIFIER})?)\s+(?:AS\s+)?({IDENTIFIER})$",
        re.IGNORECASE,
    )
    relations = []
    for relation in split_top_level_commas(from_clause):
        match = relation_pattern.match(relation)
        if not match:
            raise RuntimeError(f"unsupported Graph FROM item in {path}: {relation}")
        relations.append((match.group(1), match.group(2)))

    aliases = [alias for _, alias in relations]
    alias_lookup = {alias.lower(): alias for alias in aliases}
    selections = {alias: [] for alias in aliases}
    joins = {}
    residual = []
    for condition in split_top_level_and(where_clause):
        references = {
            alias_lookup[reference.lower()]
            for reference in re.findall(rf"\b({IDENTIFIER})\s*\.", condition)
            if reference.lower() in alias_lookup
        }
        if len(references) == 1:
            selections[next(iter(references))].append(condition)
        elif len(references) == 2:
            edge = tuple(sorted(references, key=str.lower))
            joins.setdefault(edge, []).append(condition)
        else:
            residual.append(condition)
    if residual:
        raise RuntimeError(
            f"unsupported Graph predicate in {path}: {', '.join(residual)}"
        )
    return {
        "select": select_clause,
        "where": where_clause,
        "relations": relations,
        "selections": selections,
        "joins": joins,
    }


def generate_graph_yannakakis(local_original, rewrite_name):
    """Generate a bag-preserving two-pass reducer for a local Graph query."""
    parsed = parse_graph_query(local_original)
    variant_match = re.search(r"rewriteYa(\d*)", rewrite_name, re.IGNORECASE)
    seed = int(variant_match.group(1) or 0) if variant_match else 0
    aliases = [alias for _, alias in parsed["relations"]]
    roots, _, children = spanning_forest(aliases, parsed["joins"], seed)
    if len(roots) != 1:
        raise RuntimeError(
            f"Graph join graph must be connected for reduction: {local_original}"
        )

    variant = safe_identifier(pathlib.Path(rewrite_name).stem)
    prefix = f"ya_{safe_identifier(local_original.stem)}_{variant}"
    statements = [
        "-- Locally simulated DuckDB Yannakakis-style two-pass reduction.",
        "-- EXISTS semijoins preserve duplicate base rows; the exact local join is reconstructed last.",
    ]
    base_views = {}
    for table, alias in parsed["relations"]:
        view = f"{prefix}_base_{safe_identifier(alias)}"
        base_views[alias] = view
        statement = (
            f"CREATE OR REPLACE TEMP VIEW {view} AS\n"
            f"SELECT {alias}.*\nFROM {table} AS {alias}"
        )
        if parsed["selections"][alias]:
            statement += "\nWHERE " + indent_predicates(
                parsed["selections"][alias], "  "
            )
        statements.append(statement + ";")

    up_views = {}

    def build_up(alias):
        for child in children[alias]:
            build_up(child)
        view = f"{prefix}_up_{safe_identifier(alias)}"
        up_views[alias] = view
        statement = (
            f"CREATE OR REPLACE TEMP VIEW {view} AS\n"
            f"SELECT {alias}.*\nFROM {base_views[alias]} AS {alias}"
        )
        filters = []
        for child in children[alias]:
            edge = tuple(sorted((alias, child), key=str.lower))
            predicates = parsed["joins"][edge]
            filters.append(
                f"EXISTS (SELECT 1 FROM {up_views[child]} AS {child} WHERE "
                + " AND ".join(f"({predicate})" for predicate in predicates)
                + ")"
            )
        if filters:
            statement += "\nWHERE " + "\n  AND ".join(filters)
        statements.append(statement + ";")

    root = roots[0]
    build_up(root)
    down_views = {root: f"{prefix}_down_{safe_identifier(root)}"}
    statements.append(
        f"CREATE OR REPLACE TEMP VIEW {down_views[root]} AS\n"
        f"SELECT {root}.*\nFROM {up_views[root]} AS {root};"
    )
    queue = [root]
    while queue:
        current = queue.pop(0)
        for child in children[current]:
            edge = tuple(sorted((current, child), key=str.lower))
            predicates = parsed["joins"][edge]
            child_view = f"{prefix}_down_{safe_identifier(child)}"
            down_views[child] = child_view
            statements.append(
                f"CREATE OR REPLACE TEMP VIEW {child_view} AS\n"
                f"SELECT {child}.*\nFROM {up_views[child]} AS {child}\n"
                f"WHERE EXISTS (SELECT 1 FROM {down_views[current]} AS {current} WHERE "
                + " AND ".join(f"({predicate})" for predicate in predicates)
                + ");"
            )
            queue.append(child)

    # For an acyclic query whose DISTINCT output is owned by one relation, the
    # two semijoin passes already prove that every surviving row participates
    # in the full join.  Round 3 therefore only needs the minimal projection;
    # reconstructing the complete join can reintroduce an enormous duplicate
    # intermediate before DISTINCT (Graph Q7 is the motivating case).
    output_references = {
        reference.lower()
        for reference in re.findall(rf"\b({IDENTIFIER})\s*\.", parsed["select"])
    }
    alias_lookup = {alias.lower(): alias for _, alias in parsed["relations"]}
    if (
        parsed["select"].lower().startswith("distinct ")
        and len(parsed["joins"]) == len(parsed["relations"]) - 1
        and len(output_references) == 1
        and next(iter(output_references)) in alias_lookup
    ):
        output_alias = alias_lookup[next(iter(output_references))]
        statements.append(
            "SELECT "
            + parsed["select"]
            + "\nFROM "
            + down_views[output_alias]
            + " AS "
            + output_alias
            + ";"
        )
    else:
        reduced_from = ",\n     ".join(
            f"{down_views[alias]} AS {alias}" for _, alias in parsed["relations"]
        )
        statements.append(
            "SELECT "
            + parsed["select"]
            + "\nFROM "
            + reduced_from
            + "\nWHERE "
            + indent_predicates(split_top_level_and(parsed["where"]), "  ")
            + ";"
        )
    return ("\n\n".join(statements) + "\n").encode("utf-8")


def generate_lsqb_bi3(local_original):
    """Generate the local BI-3 reducer, retaining its tag branch as EXISTS."""
    if local_original.stem != "bi-3":
        raise RuntimeError(f"unexpected BI-3 source: {local_original}")
    return b"""-- Locally simulated DuckDB Yannakakis-style two-pass reduction.
-- The tag branch remains EXISTS so multiple matching tags never multiply Message rows.
CREATE OR REPLACE TEMP VIEW ya_bi3_country_up AS
SELECT Country.* FROM Country WHERE Country.name = :country;
CREATE OR REPLACE TEMP VIEW ya_bi3_city_up AS
SELECT City.* FROM City
WHERE EXISTS (SELECT 1 FROM ya_bi3_country_up AS Country WHERE Country.id = City.PartOfCountryId);
CREATE OR REPLACE TEMP VIEW ya_bi3_moderator_up AS
SELECT ModeratorPerson.* FROM Person AS ModeratorPerson
WHERE EXISTS (SELECT 1 FROM ya_bi3_city_up AS City WHERE City.id = ModeratorPerson.LocationCityId);
CREATE OR REPLACE TEMP VIEW ya_bi3_forum_up AS
SELECT Forum.* FROM Forum
WHERE EXISTS (SELECT 1 FROM ya_bi3_moderator_up AS ModeratorPerson WHERE ModeratorPerson.id = Forum.ModeratorPersonId);
CREATE OR REPLACE TEMP VIEW ya_bi3_tagclass_up AS
SELECT TagClass.* FROM TagClass WHERE TagClass.name = :tagClass;
CREATE OR REPLACE TEMP VIEW ya_bi3_tag_up AS
SELECT Tag.* FROM Tag
WHERE EXISTS (SELECT 1 FROM ya_bi3_tagclass_up AS TagClass WHERE Tag.TypeTagClassId = TagClass.id);
CREATE OR REPLACE TEMP VIEW ya_bi3_message_tag_up AS
SELECT Message_hasTag_Tag.* FROM Message_hasTag_Tag
WHERE EXISTS (SELECT 1 FROM ya_bi3_tag_up AS Tag WHERE Message_hasTag_Tag.TagId = Tag.id);
CREATE OR REPLACE TEMP VIEW ya_bi3_message_down AS
SELECT Message.* FROM Message
WHERE EXISTS (SELECT 1 FROM ya_bi3_forum_up AS Forum WHERE Forum.id = Message.ContainerForumId)
  AND EXISTS (SELECT 1 FROM ya_bi3_message_tag_up AS Message_hasTag_Tag WHERE Message.MessageId = Message_hasTag_Tag.MessageId);
CREATE OR REPLACE TEMP VIEW ya_bi3_forum_down AS
SELECT Forum.* FROM ya_bi3_forum_up AS Forum
WHERE EXISTS (SELECT 1 FROM ya_bi3_message_down AS Message WHERE Forum.id = Message.ContainerForumId);
CREATE OR REPLACE TEMP VIEW ya_bi3_moderator_down AS
SELECT ModeratorPerson.* FROM ya_bi3_moderator_up AS ModeratorPerson
WHERE EXISTS (SELECT 1 FROM ya_bi3_forum_down AS Forum WHERE ModeratorPerson.id = Forum.ModeratorPersonId);
CREATE OR REPLACE TEMP VIEW ya_bi3_city_down AS
SELECT City.* FROM ya_bi3_city_up AS City
WHERE EXISTS (SELECT 1 FROM ya_bi3_moderator_down AS ModeratorPerson WHERE City.id = ModeratorPerson.LocationCityId);
CREATE OR REPLACE TEMP VIEW ya_bi3_country_down AS
SELECT Country.* FROM ya_bi3_country_up AS Country
WHERE EXISTS (SELECT 1 FROM ya_bi3_city_down AS City WHERE Country.id = City.PartOfCountryId);
CREATE OR REPLACE TEMP VIEW ya_bi3_message_tag_down AS
SELECT Message_hasTag_Tag.* FROM ya_bi3_message_tag_up AS Message_hasTag_Tag
WHERE EXISTS (SELECT 1 FROM ya_bi3_message_down AS Message WHERE Message.MessageId = Message_hasTag_Tag.MessageId);
CREATE OR REPLACE TEMP VIEW ya_bi3_tag_down AS
SELECT Tag.* FROM ya_bi3_tag_up AS Tag
WHERE EXISTS (SELECT 1 FROM ya_bi3_message_tag_down AS Message_hasTag_Tag WHERE Message_hasTag_Tag.TagId = Tag.id);
CREATE OR REPLACE TEMP VIEW ya_bi3_tagclass_down AS
SELECT TagClass.* FROM ya_bi3_tagclass_up AS TagClass
WHERE EXISTS (SELECT 1 FROM ya_bi3_tag_down AS Tag WHERE Tag.TypeTagClassId = TagClass.id);

SELECT Forum.id AS "forum.id",
       Forum.title AS "forum.title",
       Forum.creationDate AS "forum.creationDate",
       Forum.ModeratorPersonId AS "person.id",
       count(Message.MessageId) AS messageCount
FROM ya_bi3_message_down AS Message
JOIN ya_bi3_forum_down AS Forum ON Forum.id = Message.ContainerForumId
JOIN ya_bi3_moderator_down AS ModeratorPerson ON ModeratorPerson.id = Forum.ModeratorPersonId
JOIN ya_bi3_city_down AS City ON City.id = ModeratorPerson.LocationCityId
JOIN ya_bi3_country_down AS Country ON Country.id = City.PartOfCountryId AND Country.name = :country
WHERE EXISTS (
  SELECT 1
  FROM ya_bi3_tagclass_down AS TagClass
  JOIN ya_bi3_tag_down AS Tag ON Tag.TypeTagClassId = TagClass.id
  JOIN ya_bi3_message_tag_down AS Message_hasTag_Tag ON Message_hasTag_Tag.TagId = Tag.id
  WHERE Message.MessageId = Message_hasTag_Tag.MessageId AND TagClass.name = :tagClass)
GROUP BY Forum.id, Forum.title, Forum.creationDate, Forum.ModeratorPersonId;
"""


def generate_lsqb_bi9(local_original):
    """Generate the local BI-9 reducer with its aggregate CTE as one relation."""
    if local_original.stem != "bi-9":
        raise RuntimeError(f"unexpected BI-9 source: {local_original}")
    return b"""-- Locally simulated DuckDB Yannakakis-style two-pass reduction.
-- The grouped MPP CTE is treated as one relation in the acyclic reduction.
CREATE OR REPLACE TEMP VIEW ya_bi9_mpp_up AS
SELECT RootPostId, count(*) AS MessageCount
FROM Message
WHERE Message.creationDate BETWEEN :startDate AND :endDate
GROUP BY RootPostId;
CREATE OR REPLACE TEMP VIEW ya_bi9_post_up AS
SELECT Post.* FROM Post_View AS Post
WHERE Post.creationDate BETWEEN :startDate AND :endDate
  AND EXISTS (SELECT 1 FROM ya_bi9_mpp_up AS MPP WHERE Post.id = MPP.RootPostId);
CREATE OR REPLACE TEMP VIEW ya_bi9_person_down AS
SELECT Person.* FROM Person
WHERE EXISTS (SELECT 1 FROM ya_bi9_post_up AS Post WHERE Person.id = Post.CreatorPersonId);
CREATE OR REPLACE TEMP VIEW ya_bi9_post_down AS
SELECT Post.* FROM ya_bi9_post_up AS Post
WHERE EXISTS (SELECT 1 FROM ya_bi9_person_down AS Person WHERE Person.id = Post.CreatorPersonId);
CREATE OR REPLACE TEMP VIEW ya_bi9_mpp_down AS
SELECT MPP.* FROM ya_bi9_mpp_up AS MPP
WHERE EXISTS (SELECT 1 FROM ya_bi9_post_down AS Post WHERE Post.id = MPP.RootPostId);

SELECT Person.id AS "person.id",
       Person.firstName AS "person.firstName",
       Person.lastName AS "person.lastName",
       count(Post.id) AS threadCount,
       sum(MPP.MessageCount) AS messageCount
FROM ya_bi9_person_down AS Person
JOIN ya_bi9_post_down AS Post ON Person.id = Post.CreatorPersonId
JOIN ya_bi9_mpp_down AS MPP ON Post.id = MPP.RootPostId
WHERE Post.creationDate BETWEEN :startDate AND :endDate
GROUP BY Person.id, Person.firstName, Person.lastName;
"""


def generate_lsqb_q5_minimal(local_original):
    """Generate the exact minimal annotation plan for local LSQB Q5."""
    if local_original.stem != "q5":
        raise RuntimeError(f"unexpected LSQB Q5 source: {local_original}")
    return b"""-- Exact minimal round-3 annotation plan for local LSQB Q5.
-- The former imported artifact retained four logical semijoin views before
-- performing these same joins. Because DuckDB inlines views, that duplicated
-- scans and made the measured final statement substantially slower.
CREATE OR REPLACE TEMP VIEW ya_q5_message_tags AS
SELECT MessageId, TagId AS message_tag_id, count(*)::HUGEINT AS annot
FROM Message_hasTag_Tag_T
GROUP BY MessageId, TagId;

CREATE OR REPLACE TEMP VIEW ya_q5_replies AS
SELECT r.CommentId, m.message_tag_id, m.annot
FROM Comment_replyOf_Message_T AS r
JOIN ya_q5_message_tags AS m ON r.ParentMessageId = m.MessageId;

CREATE OR REPLACE TEMP VIEW ya_q5_comment_tags AS
SELECT CommentId, TagId AS comment_tag_id, count(*)::HUGEINT AS annot
FROM Comment_hasTag_Tag
GROUP BY CommentId, TagId;

SELECT coalesce(sum(r.annot * c.annot), 0) AS v7
FROM ya_q5_replies AS r
JOIN ya_q5_comment_tags AS c ON r.CommentId = c.CommentId
WHERE r.message_tag_id < c.comment_tag_id;
"""


def coalesce_final_count(content, source_label):
    """Make a Quorion SUM(annotation) count agree with COUNT(*) on empty input."""
    text = content.decode("utf-8")
    pattern = re.compile(r"(?im)^(\s*select\s+)SUM\s*\(\s*annot\s*\)")
    text, replacements = pattern.subn(r"\1COALESCE(SUM(annot), 0)", text)
    if replacements != 1:
        raise RuntimeError(
            f"expected one final SUM(annot) count in {source_label}, got {replacements}"
        )
    return text.encode("utf-8")


def adapt_lsqb_relation_suffix(content, source_label):
    """Adapt Quorion LSQB relation identifiers to the local DuckDB schema."""
    text = content.decode("utf-8")
    mappings = (
        ("Message_hasTag_Tag", "Message_hasTag_Tag_T"),
        ("Message_hasCreator_Person", "Message_hasCreator_Person_T"),
        ("Comment_replyOf_Message", "Comment_replyOf_Message_T"),
        ("Person_likes_Message", "Person_likes_Message_T"),
    )
    total = 0
    for old, new in mappings:
        text, replacements = re.subn(rf"\b{old}\b", new, text)
        total += replacements
    if total == 0:
        raise RuntimeError(f"no LSQB relation suffix adapted in {source_label}")
    # Quorion q5 has a pinned source typo: a trailing comma before FROM.
    text, trailing_comma = re.subn(
        r"(?i)(\bTagId\s+as\s+M_TagId)\s*,\s*(from\b)", r"\1 \2", text
    )
    if "q5/rewriteYa0.sql" in source_label and trailing_comma != 1:
        raise RuntimeError(f"expected the LSQB q5 trailing-comma fix in {source_label}")
    return coalesce_final_count(text.encode("utf-8"), source_label)


def adapt_tpch_rewrite(local_original, rewrite, content):
    """Apply pinned, query-specific DuckDB adaptations to Quorion TPC-H SQL."""
    text = content.decode("utf-8")
    query = local_original.stem
    source_label = rewrite.as_posix()
    if query == "5":
        text, dates = re.subn(
            r"(?i)o_orderdate\s*<\s*DATE\s*'1995-01-01'",
            "o_orderdate < DATE '1994-01-01' + INTERVAL '1' YEAR",
            text,
        )
        if dates == 0:
            raise RuntimeError(f"expected TPC-H q5 date adaptation in {source_label}")
        if rewrite.name in ("rewriteYa0.sql", "rewriteYa2.sql"):
            pattern = re.compile(
                r"(?i)(create\s+or\s+replace\s+view\s+aggJoin\d+\s+as\s+select\s+)v42(\s+from\s+aggView\d+\s+where\s+v4\s*=\s+v5[01]\s*;)"
            )
            text, projections = pattern.subn(r"\1v42, v49\2", text)
            if projections != 1:
                raise RuntimeError(
                    f"expected one TPC-H q5 v49 projection fix in {source_label}"
                )
    elif query == "10":
        text, dates = re.subn(
            r"(?i)o_orderdate\s*<\s*DATE\s*'1994-01-01'",
            "o_orderdate < DATE '1993-10-01' + INTERVAL '3' MONTH",
            text,
        )
        if dates == 0:
            raise RuntimeError(f"expected TPC-H q10 date adaptation in {source_label}")
    elif query == "16":
        predicate = (
            "ps_suppkey NOT IN (SELECT s_suppkey FROM supplier "
            "WHERE s_comment LIKE '%Customer%Complaints%')"
        )
        partsupp_scans = len(
            re.findall(r"(?i)\bfrom\s+partsupp\s+AS\s+partsupp\b", text)
        )
        text = re.sub(
            r"(?i)(\bfrom\s+partsupp\s+AS\s+partsupp)\s+where\b",
            rf"\1 WHERE ({predicate}) AND",
            text,
        )
        text = re.sub(
            r"(?i)(\bfrom\s+partsupp\s+AS\s+partsupp)\s*\)",
            rf"\1 WHERE ({predicate}))",
            text,
        )
        if text.count(predicate) != partsupp_scans:
            raise RuntimeError(
                f"did not adapt every TPC-H q16 partsupp scan in {source_label}"
            )
        if rewrite.name == "rewriteYa0.sql":
            text, casts = re.subn(
                r"(?i)\bannot\s+as\s+v15\b", "CAST(annot AS BIGINT) AS v15", text
            )
            if casts != 1:
                raise RuntimeError(f"expected TPC-H q16 count cast in {source_label}")
    else:
        raise RuntimeError(f"no TPC-H mismatch adapter for query {query}")
    return text.encode("utf-8")


def add_tpch_helper(local_original, content):
    """Make copied TPC-H q7/q18 rewrites independent of pre-created helpers."""
    if local_original.stem == "7":
        text = content.decode("utf-8")
        text, predicates = re.subn(
            r"(?i)(create\s+or\s+replace\s+view\s+n1Aux\d+\s+as\s+select\s+"
            r"n_nationkey\s+as\s+v4\s*,\s*n_name\s+as\s+v43\s+from\s+nation)\s*;",
            r"\1 WHERE n_name = 'FRANCE';",
            text,
        )
        if predicates != 1:
            raise RuntimeError(
                f"expected one missing TPC-H q7 FRANCE predicate in copied rewrite, got {predicates}"
            )
        content = text.encode("utf-8")
        helper = b"""-- DuckDB helper required by the local TPC-H q7 input.
CREATE OR REPLACE TEMP VIEW lineitemwithyear AS
SELECT lineitem.*, year(l_shipdate) AS l_year FROM lineitem;

"""
    elif local_original.stem == "18":
        helper = b"""-- DuckDB helper required by the local TPC-H q18 input.
CREATE OR REPLACE TEMP VIEW q18_inner AS
SELECT l_orderkey AS v1_orderkey
FROM lineitem
GROUP BY l_orderkey
HAVING SUM(l_quantity) > 312;

"""
    else:
        raise RuntimeError(f"no TPC-H helper for {local_original}")
    return helper + content


def source_commit(source_root):
    result = subprocess.run(
        ["git", "-C", str(source_root), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def fallback_original(suite, local_original, upstream_suite):
    if suite == "graph":
        # Local Graph numbering does not correspond to Quorion's q1a/q1b/etc.
        return None
    if suite in ("lsqb", "tpch"):
        upstream_name = local_original.stem
        if not upstream_name.startswith("q"):
            upstream_name = "q" + upstream_name
    else:
        upstream_name = local_original.stem
    candidate = upstream_suite / upstream_name / "query.sql"
    return candidate if candidate.is_file() else None


def expected_imports(source_root):
    imports = []
    manifest_rows = []

    for suite, (local_dir_name, upstream_dir_name, destination_name) in SUITES.items():
        local_dir = REPOSITORY_ROOT / local_dir_name
        upstream_suite = source_root / "query" / upstream_dir_name
        destination = REPOSITORY_ROOT / destination_name
        if not local_dir.is_dir():
            raise RuntimeError(f"missing local original directory: {local_dir}")
        if not upstream_suite.is_dir():
            raise RuntimeError(f"missing Quorion query directory: {upstream_suite}")

        upstream_by_digest = {}
        for upstream_original in sorted(upstream_suite.glob("*/query.sql")):
            digest = normalized_digest(upstream_original)
            upstream_by_digest.setdefault(digest, []).append(upstream_original)

        for local_original in sorted(local_dir.glob("*.sql")):
            local_digest = normalized_digest(local_original)
            matches = upstream_by_digest.get(local_digest, [])
            if suite != "job" and len(matches) > 1:
                paths = ", ".join(str(path) for path in matches)
                raise RuntimeError(f"ambiguous source match for {local_original}: {paths}")

            matched = suite != "job" and len(matches) == 1
            upstream_original = matches[0] if matched else fallback_original(
                suite, local_original, upstream_suite
            )
            upstream_digest = normalized_digest(upstream_original) if upstream_original else ""
            rewrites = (
                sorted(upstream_original.parent.glob("rewriteYa*.sql"))
                if upstream_original
                else []
            )
            rewrite_entries = [(rewrite, rewrite.name) for rewrite in rewrites]
            if suite == "lsqb" and local_original.stem == "q2" and not rewrites:
                one_bag = upstream_original.parent / "rewrite0.sql"
                if not one_bag.is_file():
                    raise RuntimeError(f"missing LSQB q2 one-bag fallback: {one_bag}")
                rewrite_entries = [(one_bag, "rewriteYa0.sql")]
            elif not rewrite_entries:
                rewrite_entries = [(None, "rewriteYa0.sql")]

            for rewrite, rewrite_name in rewrite_entries:
                artifact = destination / f"{local_original.stem}_{rewrite_name}"
                if suite == "job":
                    source_rewrite = (
                        rewrite.relative_to(source_root).as_posix() if rewrite else ""
                    )
                    content = generate_job_yannakakis(
                        local_original, rewrite_name, source_rewrite
                    )
                    status = (
                        "generated_duckdb_sum"
                        if rewrite
                        else "generated_duckdb_sum_fallback"
                    )
                elif suite == "graph":
                    if matched and rewrite:
                        content = coalesce_final_count(
                            rewrite.read_bytes(), rewrite.as_posix()
                        )
                        status = "adapted_duckdb_empty_count"
                    else:
                        content = generate_graph_yannakakis(
                            local_original, rewrite_name
                        )
                        status = "simulated_duckdb_yannakakis"
                elif suite == "lsqb":
                    if local_original.stem == "bi-3":
                        content = generate_lsqb_bi3(local_original)
                        status = "simulated_duckdb_yannakakis"
                    elif local_original.stem == "bi-9":
                        content = generate_lsqb_bi9(local_original)
                        status = "simulated_duckdb_yannakakis"
                    elif local_original.stem == "q5":
                        content = generate_lsqb_q5_minimal(local_original)
                        status = "generated_minimal_annotation"
                    elif local_original.stem == "q2" and rewrite:
                        content = (
                            b"-- Simulated one-bag GHD fallback: the cyclic triangle is one bag,\n"
                            b"-- so there is no inter-bag semijoin before DuckDB executes the bag join.\n"
                            + rewrite.read_bytes()
                        )
                        status = "simulated_ghd_one_bag"
                    elif matched and rewrite:
                        content = coalesce_final_count(
                            rewrite.read_bytes(), rewrite.as_posix()
                        )
                        status = "adapted_duckdb_empty_count"
                    elif local_original.stem in ("q4", "q5", "q7", "q8") and rewrite:
                        content = adapt_lsqb_relation_suffix(
                            rewrite.read_bytes(), rewrite.as_posix()
                        )
                        status = "adapted_duckdb_relation_suffix"
                    else:
                        raise RuntimeError(
                            f"no LSQB Yannakakis adaptation for {local_original}"
                        )
                elif suite == "tpch":
                    if matched and rewrite:
                        content = rewrite.read_bytes()
                        if local_original.stem in ("7", "18"):
                            content = add_tpch_helper(local_original, content)
                            status = "adapted_duckdb_self_contained"
                        else:
                            status = "copied"
                    elif rewrite and local_original.stem in ("5", "10", "16"):
                        content = adapt_tpch_rewrite(
                            local_original, rewrite, rewrite.read_bytes()
                        )
                        status = "adapted_duckdb_local_semantics"
                    else:
                        raise RuntimeError(
                            f"no TPC-H Yannakakis adaptation for {local_original}"
                        )
                else:
                    raise RuntimeError(f"unsupported Yannakakis suite: {suite}")
                # Keep generated artifacts stable and avoid carrying source
                # checkout whitespace (several files end with blank lines).
                content = content.rstrip() + b"\n"
                imports.append((artifact, content))
                manifest_rows.append(
                    (
                        suite,
                        local_original.relative_to(REPOSITORY_ROOT).as_posix(),
                        (
                            upstream_original.relative_to(source_root).as_posix()
                            if upstream_original
                            else ""
                        ),
                        local_digest,
                        upstream_digest,
                        rewrite.relative_to(source_root).as_posix() if rewrite else "",
                        artifact.relative_to(REPOSITORY_ROOT).as_posix(),
                        status,
                    )
                )

    for suite, (local_dir_name, _, destination_name) in SUITES.items():
        originals = {
            path.stem for path in (REPOSITORY_ROOT / local_dir_name).glob("*.sql")
        }
        coverage = {
            path.name.split("_rewriteYa", 1)[0]
            for path, content in imports
            if path.parent.name == destination_name and content.strip()
        }
        missing = sorted(originals - coverage)
        if missing:
            raise RuntimeError(
                f"{suite.upper()} Yannakakis coverage is incomplete: "
                + ", ".join(missing)
            )
    empty_artifacts = [path for path, content in imports if not content.strip()]
    if empty_artifacts:
        raise RuntimeError(
            "Yannakakis import produced empty artifacts: "
            + ", ".join(path.as_posix() for path in empty_artifacts)
        )
    return imports, manifest_rows


def manifest_content(commit, rows):
    lines = [
        f"# source_url\t{QUORION_URL}",
        f"# source_commit\t{commit}",
        "suite\tlocal_original\tupstream_original\tlocal_normalized_sha256\t"
        "upstream_normalized_sha256\tupstream_rewrite\tlocal_artifact\tstatus",
    ]
    lines.extend("\t".join(row) for row in rows)
    return ("\n".join(lines) + "\n").encode("utf-8")


def verify_no_unmanaged_sql(imports):
    expected = {path.resolve() for path, _ in imports}
    for _, _, destination_name in SUITES.values():
        destination = REPOSITORY_ROOT / destination_name
        if not destination.exists():
            continue
        for existing in destination.glob("*.sql"):
            if existing.resolve() not in expected:
                raise RuntimeError(f"unmanaged SQL file in import directory: {existing}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("quorion_root", type=pathlib.Path)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify committed artifacts instead of writing them",
    )
    args = parser.parse_args()
    source_root = args.quorion_root.resolve()
    commit = source_commit(source_root)
    if commit != QUORION_COMMIT:
        parser.error(
            f"Quorion checkout is {commit}, expected pinned commit {QUORION_COMMIT}"
        )

    imports, rows = expected_imports(source_root)
    verify_no_unmanaged_sql(imports)
    manifest_path = REPOSITORY_ROOT / MANIFEST_NAME
    expected_files = imports + [(manifest_path, manifest_content(commit, rows))]

    if args.check:
        mismatches = []
        for path, content in expected_files:
            if not path.is_file() or path.read_bytes() != content:
                mismatches.append(path)
        if mismatches:
            for path in mismatches:
                print(f"mismatch: {path}", file=sys.stderr)
            return 1
        print(f"Verified {len(imports)} Yannakakis artifacts against {commit}.")
        return 0

    for path, content in expected_files:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    copied = sum(1 for row in rows if row[-1] == "copied")
    generated = sum(1 for row in rows if row[-1].startswith("generated_"))
    adapted = sum(1 for row in rows if row[-1].startswith("adapted_"))
    simulated = sum(1 for row in rows if row[-1].startswith("simulated_"))
    print(
        f"Imported {copied}, adapted {adapted}, simulated {simulated}, and generated "
        f"{generated} Yannakakis-style rewrites from {commit}; no blank placeholders."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
