#!/usr/bin/env python3
"""Generate exact two-pass DSB reducers with the local round-3 rewrites."""

import argparse
import hashlib
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "dsb_yannakakis_rewrite_manifest.tsv"


def relation(table, alias=None):
    return (table, alias or table)


# Each edge is (left alias, left column, right alias, right column). Multiple
# entries for one alias pair form one composite semijoin condition.
SPECS = {
    "dsb_agg": {
        "query013": (
            [relation("store_sales"), relation("store"), relation("customer_demographics"),
             relation("household_demographics"), relation("customer_address"), relation("date_dim")],
            [("store_sales", "ss_store_sk", "store", "s_store_sk"),
             ("store_sales", "ss_cdemo_sk", "customer_demographics", "cd_demo_sk"),
             ("store_sales", "ss_hdemo_sk", "household_demographics", "hd_demo_sk"),
             ("store_sales", "ss_addr_sk", "customer_address", "ca_address_sk"),
             ("store_sales", "ss_sold_date_sk", "date_dim", "d_date_sk")]),
        "query019": (
            [relation("store_sales"), relation("date_dim"), relation("item"), relation("customer"),
             relation("customer_address"), relation("store")],
            [("store_sales", "ss_sold_date_sk", "date_dim", "d_date_sk"),
             ("store_sales", "ss_item_sk", "item", "i_item_sk"),
             ("store_sales", "ss_customer_sk", "customer", "c_customer_sk"),
             ("customer", "c_current_addr_sk", "customer_address", "ca_address_sk"),
             ("store_sales", "ss_store_sk", "store", "s_store_sk")]),
        "query072": (
            [relation("catalog_sales"), relation("inventory"), relation("warehouse"), relation("item"),
             relation("customer_demographics"), relation("household_demographics"),
             relation("date_dim", "d1"), relation("date_dim", "d2"), relation("date_dim", "d3"),
             relation("promotion"), relation("catalog_returns")],
            [("catalog_sales", "cs_item_sk", "inventory", "inv_item_sk"),
             ("inventory", "inv_warehouse_sk", "warehouse", "w_warehouse_sk"),
             ("catalog_sales", "cs_item_sk", "item", "i_item_sk"),
             ("catalog_sales", "cs_bill_cdemo_sk", "customer_demographics", "cd_demo_sk"),
             ("catalog_sales", "cs_bill_hdemo_sk", "household_demographics", "hd_demo_sk"),
             ("catalog_sales", "cs_sold_date_sk", "d1", "d_date_sk"),
             ("inventory", "inv_date_sk", "d2", "d_date_sk"),
             ("catalog_sales", "cs_ship_date_sk", "d3", "d_date_sk"),
             ("catalog_sales", "cs_promo_sk", "promotion", "p_promo_sk"),
             ("catalog_sales", "cs_item_sk", "catalog_returns", "cr_item_sk"),
             ("catalog_sales", "cs_order_number", "catalog_returns", "cr_order_number")]),
        "query100": (
            [relation("store_sales", "s1"), relation("store_sales", "s2"), relation("item", "item1"),
             relation("item", "item2"), relation("date_dim"), relation("customer"),
             relation("customer_address"), relation("customer_demographics")],
            [("s1", "ss_ticket_number", "s2", "ss_ticket_number"),
             ("s1", "ss_item_sk", "item1", "i_item_sk"),
             ("s2", "ss_item_sk", "item2", "i_item_sk"),
             ("s1", "ss_sold_date_sk", "date_dim", "d_date_sk"),
             ("s1", "ss_customer_sk", "customer", "c_customer_sk"),
             ("customer", "c_current_addr_sk", "customer_address", "ca_address_sk"),
             ("customer", "c_current_cdemo_sk", "customer_demographics", "cd_demo_sk")]),
        "query101": (
            [relation("store_sales"), relation("store_returns"), relation("web_sales"),
             relation("date_dim", "d1"), relation("date_dim", "d2"), relation("item"),
             relation("customer"), relation("customer_address"), relation("household_demographics")],
            [("store_sales", "ss_ticket_number", "store_returns", "sr_ticket_number"),
             ("store_sales", "ss_item_sk", "store_returns", "sr_item_sk"),
             ("store_sales", "ss_customer_sk", "web_sales", "ws_bill_customer_sk"),
             ("store_sales", "ss_item_sk", "item", "i_item_sk"),
             ("store_sales", "ss_customer_sk", "customer", "c_customer_sk"),
             ("customer", "c_current_addr_sk", "customer_address", "ca_address_sk"),
             ("customer", "c_current_hdemo_sk", "household_demographics", "hd_demo_sk"),
             ("store_returns", "sr_returned_date_sk", "d1", "d_date_sk"),
             ("web_sales", "ws_sold_date_sk", "d2", "d_date_sk")]),
        "query102": (
            [relation("store_sales", "ss"), relation("web_sales", "ws"), relation("date_dim", "d1"),
             relation("date_dim", "d2"), relation("customer"), relation("inventory"), relation("store"),
             relation("warehouse"), relation("item"), relation("customer_demographics"),
             relation("household_demographics"), relation("customer_address")],
            [("ss", "ss_item_sk", "ws", "ws_item_sk"),
             ("ss", "ss_sold_date_sk", "d1", "d_date_sk"),
             ("ws", "ws_sold_date_sk", "d2", "d_date_sk"),
             ("ss", "ss_customer_sk", "customer", "c_customer_sk"),
             ("ss", "ss_item_sk", "inventory", "inv_item_sk"),
             ("ss", "ss_sold_date_sk", "inventory", "inv_date_sk"),
             ("ws", "ws_warehouse_sk", "warehouse", "w_warehouse_sk"),
             ("store", "s_state", "warehouse", "w_state"),
             ("ss", "ss_item_sk", "item", "i_item_sk"),
             ("customer", "c_current_cdemo_sk", "customer_demographics", "cd_demo_sk"),
             ("customer", "c_current_hdemo_sk", "household_demographics", "hd_demo_sk"),
             ("customer", "c_current_addr_sk", "customer_address", "ca_address_sk")]),
    },
    "dsb_spj": {
        "query018": (
            [relation("catalog_sales"), relation("customer_demographics"), relation("customer"),
             relation("customer_address"), relation("date_dim"), relation("item")],
            [("catalog_sales", "cs_bill_cdemo_sk", "customer_demographics", "cd_demo_sk"),
             ("catalog_sales", "cs_bill_customer_sk", "customer", "c_customer_sk"),
             ("customer", "c_current_addr_sk", "customer_address", "ca_address_sk"),
             ("catalog_sales", "cs_sold_date_sk", "date_dim", "d_date_sk"),
             ("catalog_sales", "cs_item_sk", "item", "i_item_sk")]),
        "query019": (
            [relation("store_sales"), relation("date_dim"), relation("item"), relation("customer"),
             relation("customer_address"), relation("store")],
            [("store_sales", "ss_sold_date_sk", "date_dim", "d_date_sk"),
             ("store_sales", "ss_item_sk", "item", "i_item_sk"),
             ("store_sales", "ss_customer_sk", "customer", "c_customer_sk"),
             ("customer", "c_current_addr_sk", "customer_address", "ca_address_sk"),
             ("store_sales", "ss_store_sk", "store", "s_store_sk")]),
        "query025": (
            [relation("store_sales", "ss"), relation("store_returns", "sr"), relation("catalog_sales", "cs"),
             relation("date_dim", "d1"), relation("date_dim", "d2"), relation("date_dim", "d3"),
             relation("store"), relation("item")],
            [("ss", "ss_customer_sk", "sr", "sr_customer_sk"),
             ("ss", "ss_item_sk", "sr", "sr_item_sk"),
             ("ss", "ss_ticket_number", "sr", "sr_ticket_number"),
             ("sr", "sr_customer_sk", "cs", "cs_bill_customer_sk"),
             ("sr", "sr_item_sk", "cs", "cs_item_sk"),
             ("ss", "ss_sold_date_sk", "d1", "d_date_sk"),
             ("sr", "sr_returned_date_sk", "d2", "d_date_sk"),
             ("cs", "cs_sold_date_sk", "d3", "d_date_sk"),
             ("ss", "ss_store_sk", "store", "s_store_sk"),
             ("ss", "ss_item_sk", "item", "i_item_sk")]),
        "query072": None,
        "query085": (
            [relation("web_sales"), relation("web_returns"), relation("web_page"),
             relation("customer_demographics", "cd1"), relation("customer_demographics", "cd2"),
             relation("customer_address"), relation("date_dim"), relation("reason")],
            [("web_sales", "ws_item_sk", "web_returns", "wr_item_sk"),
             ("web_sales", "ws_order_number", "web_returns", "wr_order_number"),
             ("web_sales", "ws_web_page_sk", "web_page", "wp_web_page_sk"),
             ("web_sales", "ws_sold_date_sk", "date_dim", "d_date_sk"),
             ("web_returns", "wr_refunded_cdemo_sk", "cd1", "cd_demo_sk"),
             ("web_returns", "wr_returning_cdemo_sk", "cd2", "cd_demo_sk"),
             ("web_returns", "wr_refunded_addr_sk", "customer_address", "ca_address_sk"),
             ("web_returns", "wr_reason_sk", "reason", "r_reason_sk")]),
        "query099": (
            [relation("catalog_sales"), relation("warehouse"), relation("ship_mode"),
             relation("call_center"), relation("date_dim")],
            [("catalog_sales", "cs_warehouse_sk", "warehouse", "w_warehouse_sk"),
             ("catalog_sales", "cs_ship_mode_sk", "ship_mode", "sm_ship_mode_sk"),
             ("catalog_sales", "cs_call_center_sk", "call_center", "cc_call_center_sk"),
             ("catalog_sales", "cs_ship_date_sk", "date_dim", "d_date_sk")]),
    },
}

# Q72 is shared by the aggregate and SPJ workloads; copy the same relation tree.
SPECS["dsb_spj"]["query072"] = SPECS["dsb_agg"]["query072"]


def safe(value):
    return re.sub(r"[^A-Za-z0-9_]", "_", value)


def round3_path(suite, query):
    short = str(int(query[len("query") :]))
    return ROOT / f"{suite}_rewrite" / f"q{short}_r.sql"


def replace_relation(sql, table, alias, replacement):
    if alias == table:
        # Replace relation declarations, never qualifiers such as date_dim.d_year.
        pattern = re.compile(rf"\b{re.escape(table)}\b(?!\s*\.)", re.IGNORECASE)
    else:
        pattern = re.compile(
            rf"\b{re.escape(table)}\s+(?:AS\s+)?{re.escape(alias)}\b",
            re.IGNORECASE,
        )
    sql, count = pattern.subn(f"{replacement} AS {alias}", sql)
    if count == 0:
        raise RuntimeError(f"round-3 SQL does not scan {table} AS {alias}")
    return sql


def generate(suite, query, relations, edges):
    aliases = [alias for _, alias in relations]
    if len(set(aliases)) != len(aliases):
        raise RuntimeError(f"duplicate aliases in {suite}/{query}")
    edge_conditions = {}
    adjacency = {alias: set() for alias in aliases}
    for left, left_col, right, right_col in edges:
        if left not in adjacency or right not in adjacency:
            raise RuntimeError(f"unknown edge alias in {suite}/{query}: {left}-{right}")
        key = tuple(sorted((left, right)))
        edge_conditions.setdefault(key, []).append((left, left_col, right, right_col))
        adjacency[left].add(right)
        adjacency[right].add(left)

    root = aliases[0]
    parent = {root: None}
    children = {alias: [] for alias in aliases}
    queue = [root]
    while queue:
        current = queue.pop(0)
        for neighbor in sorted(adjacency[current]):
            if neighbor in parent:
                continue
            parent[neighbor] = current
            children[current].append(neighbor)
            queue.append(neighbor)
    if len(parent) != len(aliases) or len(edge_conditions) != len(aliases) - 1:
        raise RuntimeError(f"configured DSB reducer is not a tree: {suite}/{query}")

    prefix = f"ya_{safe(query)}"
    statements = [
        f"-- Generated exact two-pass DSB reducer for {suite}/{query}.",
        "-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.",
    ]
    base = {}
    for table, alias in relations:
        base[alias] = f"{prefix}_base_{safe(alias)}"
        statements.append(
            f"CREATE OR REPLACE TEMP VIEW {base[alias]} AS\n"
            f"SELECT {alias}.* FROM {table} AS {alias};"
        )

    up = {}

    def build_up(alias):
        for child in children[alias]:
            build_up(child)
        up[alias] = f"{prefix}_up_{safe(alias)}"
        filters = []
        for child in children[alias]:
            predicates = []
            for left, left_col, right, right_col in edge_conditions[tuple(sorted((alias, child)))]:
                predicates.append(f"{left}.{left_col} = {right}.{right_col}")
            filters.append(
                f"EXISTS (SELECT 1 FROM {up[child]} AS {child} WHERE "
                + " AND ".join(predicates)
                + ")"
            )
        statement = f"CREATE OR REPLACE TEMP VIEW {up[alias]} AS\nSELECT {alias}.* FROM {base[alias]} AS {alias}"
        if filters:
            statement += "\nWHERE " + "\n  AND ".join(filters)
        statements.append(statement + ";")

    build_up(root)
    down = {root: f"{prefix}_down_{safe(root)}"}
    statements.append(
        f"CREATE OR REPLACE TEMP VIEW {down[root]} AS\nSELECT {root}.* FROM {up[root]} AS {root};"
    )
    queue = [root]
    while queue:
        current = queue.pop(0)
        for child in children[current]:
            down[child] = f"{prefix}_down_{safe(child)}"
            predicates = []
            for left, left_col, right, right_col in edge_conditions[tuple(sorted((current, child)))]:
                predicates.append(f"{left}.{left_col} = {right}.{right_col}")
            statements.append(
                f"CREATE OR REPLACE TEMP VIEW {down[child]} AS\n"
                f"SELECT {child}.* FROM {up[child]} AS {child}\n"
                f"WHERE EXISTS (SELECT 1 FROM {down[current]} AS {current} WHERE "
                + " AND ".join(predicates)
                + ");"
            )
            queue.append(child)

    source = round3_path(suite, query)
    if not source.is_file():
        raise RuntimeError(f"missing DSB round-3 rewrite: {source}")
    round3 = source.read_text(encoding="utf-8").strip()
    for table, alias in sorted(relations, key=lambda entry: len(entry[1]), reverse=True):
        round3 = replace_relation(round3, table, alias, down[alias])
    statements.append(round3)
    return "\n\n".join(statements).rstrip() + "\n", source


def expected():
    artifacts = []
    manifest_rows = []
    for suite, queries in SPECS.items():
        destination = ROOT / f"{suite}_yannakakis_rewrite"
        for query, spec in sorted(queries.items()):
            relations, edges = spec
            content, round3 = generate(suite, query, relations, edges)
            original = ROOT / suite / f"{query}.sql"
            artifact = destination / f"{query}_rewriteYa0.sql"
            artifacts.append((artifact, content.encode("utf-8")))
            manifest_rows.append(
                (suite, original.relative_to(ROOT).as_posix(),
                 round3.relative_to(ROOT).as_posix(), artifact.relative_to(ROOT).as_posix(),
                 hashlib.sha256(original.read_bytes()).hexdigest(),
                 hashlib.sha256(round3.read_bytes()).hexdigest())
            )
    lines = [
        "suite\toriginal\tround3_rewrite\tartifact\toriginal_sha256\tround3_sha256",
        *("\t".join(row) for row in manifest_rows),
    ]
    artifacts.append((MANIFEST, ("\n".join(lines) + "\n").encode("utf-8")))
    return artifacts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    artifacts = expected()
    if args.check:
        mismatches = [path for path, content in artifacts if not path.is_file() or path.read_bytes() != content]
        for path in mismatches:
            print(f"mismatch: {path}")
        return bool(mismatches)
    for path, content in artifacts:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    print(f"Generated {len(artifacts) - 1} DSB Yannakakis rewrite artifacts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
