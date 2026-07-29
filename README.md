## Yannakakis<sup>+</sup>

This repository contains the implementation of **Yannakakis<sup>+</sup>**, ported to
[DuckDB v1.5.0](https://github.com/duckdb/duckdb/tree/v1.5.0). It provides a customized
version of DuckDB with:

- GYO-based join planning for acyclic queries.
- Bloom-filter and exact hash-filter backends for Yan+ semi-joins. Bloom is the default.
- Aggregation push-down in the query plan.
- Experimental, plan-derived virtual bags that let Yan+ insert semi-join filters for cyclic queries.

### Cyclic-query scope

When GYO detects a cyclic core, DuckDB's v1.5 dynamic-programming enumerator still
selects the binary join plan. Yan+ derives one virtual bag boundary from that selected
plan and treats its existing left and right subtrees as the probe and build bags for
semi-join-filter insertion.

The virtual bag is optimizer metadata, not a new bag or SCOJ operator. The selected
join topology, join conditions, and residual predicates remain unchanged. Existing
`CREATE_BF` and `USE_BF` wrappers build and apply the filter around the complete
subtrees, after which the original DuckDB join still executes. This is intended to
provide experimental cyclic-query coverage; it does not enumerate all GHD
decompositions or implement a complete GHD/SCOJ execution strategy. Aggregate
pushdown remains acyclic-only: for a cyclic aggregate query, the native DuckDB
aggregate stays above the filter-wrapped join tree.

### Configuration

The Yan+ settings are local DuckDB settings:

| Setting | Default | Purpose |
| --- | --- | --- |
| `yanplus_enable` | `true` | Enable or disable the Yan+ optimizer. |
| `yanplus_cyclic_bags` | `true` | Enable plan-derived virtual bags for cyclic queries. |
| `yanplus_semijoin_filter` | `BLOOM` | Select `BLOOM` or exact `HASH` semi-join filters. |

DuckDB now defaults to at most 64 threads: it uses 64 on the 72-logical-CPU
experiment host and still uses fewer on a smaller host. An explicit
`SET threads = N` remains an override; `RESET threads` restores the capped
default.

For example, the same query can be compared with the two filter backends using:

```sql
SET yanplus_enable = true;
SET yanplus_cyclic_bags = true;

SET yanplus_semijoin_filter = 'bloom'; -- default
-- run the query

SET yanplus_semijoin_filter = 'hash';
-- run the same query
```

### Verify semi-join operator selection

Use `EXPLAIN` on the same query after changing only
`yanplus_semijoin_filter`. A cyclic plan using the experimental virtual-bag
path contains both `CREATE_BF` and `USE_BF`; each wrapper reports
`Semi-Join Filter Type: BLOOM` or `Semi-Join Filter Type: HASH`.

For example, after loading an LSQB database:

```sql
SET yanplus_enable = true;
SET yanplus_cyclic_bags = true;

SET yanplus_semijoin_filter = 'bloom';
EXPLAIN
SELECT count(*)
FROM Person_knows_Person, Comment, Post
WHERE Person_knows_Person.Person1Id = Comment.hasCreator_PersonId
  AND Person_knows_Person.Person2Id = Post.hasCreator_PersonId
  AND Comment.replyOf_PostId = Post.PostId;

SET yanplus_semijoin_filter = 'hash';
EXPLAIN
SELECT count(*)
FROM Person_knows_Person, Comment, Post
WHERE Person_knows_Person.Person1Id = Comment.hasCreator_PersonId
  AND Person_knows_Person.Person2Id = Post.hasCreator_PersonId
  AND Comment.replyOf_PostId = Post.PostId;
```

The LSQB-Q2 regression runs this triangle query with native DuckDB, Bloom,
and Hash, checks equal results, and checks the physical-plan markers:

```sh
build/release/test/unittest \
  test/sql/optimizer/plan/test_yanplus_lsqb_q2.test
```

## Build

You can build this repository in the same way as the original DuckDB. A `Makefile` wraps the build process. For available build targets and configuration flags, see the [DuckDB Build Configuration Guide](https://duckdb.org/docs/stable/dev/building/build_configuration.html).

```bash
make                   # Build optimized release version
make release           # Same as 'make'
make debug             # Build with debug symbols
GEN=ninja make         # Use Ninja as backend
BUILD_BENCHMARK=1 make # Build with benchmark support
```

For the origin-versus-Yan+ experiment, build two independent CMake caches:

```sh
./build_duckdb.sh
```

This produces:

- `build/duckdb_origin/duckdb`, compiled with `ENABLE_YANPLUS=OFF`. The Yan+
  settings and optimizer entry path are unavailable, so joins use DuckDB
  v1.5's native optimizer path.
- `build/duckdb_YanPlus/duckdb`, compiled with `ENABLE_YANPLUS=ON`. Yan+ is
  enabled and its semi-join filter defaults to `BLOOM`.

Common CMake options can be passed once and are applied to both builds, for
example `./build_duckdb.sh -DNATIVE_ARCH=ON`. Set `BUILD_JOBS` to
control compilation parallelism. Use `YANPLUS_FRESH_BUILD=1` after changing
toolchains or options so neither dedicated cache retains stale configuration.
Both executables report `v1.5.0-yanplus`; override this only when needed with
`DUCKDB_EXPERIMENT_VERSION`. Do not copy these generated executables to the
tracked top-level `duckdb_origin` and `duckdb_YanPlus` paths.

The compile-disabled origin is the CLI control build from this branch: normal
SQL follows the native optimizer path and cannot enable Yan+, although dormant
lower-level Yan+ implementation objects remain linked. It is therefore not a
byte-for-byte build of the upstream v1.5.0 tag. Use the unmodified `v1.5.0` tag
when a strict source-clean upstream binary is required.

## Baselines

- **DuckDB v1.5.0**: [https://github.com/duckdb/duckdb/tree/v1.5.0](https://github.com/duckdb/duckdb/tree/v1.5.0)
- **RPT (Robust Predicate Transfer)**: [https://github.com/embryo-labs/Robust-Predicate-Transfer](https://github.com/embryo-labs/Robust-Predicate-Transfer)

- **Parachute**: https://github.com/utndatasystems/parachute
- **SYA**: https://github.com/UHasselt-DSI-Data-Systems-Lab/code-reproducability-yannakakis-vldb2025
- **Yannakakis<sup>+</sup> (rewrite)**: https://github.com/hkustDB/Quorion

## Benchmark

The reproducible Bloom-versus-Hash experiment is documented in
[`benchmark/yanplus/README.md`](benchmark/yanplus/README.md). It runs the same cyclic
query and plan with only the semi-join-filter backend changed.

On the 72-logical-CPU experiment host, all provided experiment launchers use
64 DuckDB threads and Linux `taskset --cpu-list 0-15,24-71`. Thus logical CPUs
16–23 are excluded. The query-suite launchers disable internal pinning and
rebuild the worker pool before timing. The v1.5 scheduler also maps automatic
startup pinning onto the inherited allowed-CPU mask instead of global
sequential CPU IDs, which keeps the benchmark runner inside the same mask.

```sh
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --output benchmark/yanplus/results.csv
```

To run all committed Graph, LSQB, DSB, TPC-H, and JOB queries with both
compiled variants, plus the committed DSB rewritten queries:

```sh
./batch_run.sh
```

Rewriter is a SQL-query baseline, not a third DuckDB build. It runs the
generated `*_rewrite` SQL with `build/duckdb_origin/duckdb`. Setup
`CREATE VIEW` statements are made temporary and run outside the timed region;
the final rewritten query receives the same warm-up and timed repetitions as
origin and Yan+. The default rewriter selection is `dsb`, currently six
`dsb_agg_rewrite` queries and five `dsb_spj_rewrite` queries. DSB SPJ query 99
has no committed rewrite, and there is no committed JOB rewrite suite.

The database files default to the repository root and must be named
`graph_db`, `lsqb_db`, `dsb_db`, `tpch_db`, and `job_db`. Override their
directory with `YANPLUS_DATABASE_ROOT`. A smaller batch can name suites, for
example:

```sh
YANPLUS_REPETITIONS=1 ./batch_run.sh lsqb tpch
```

Select or skip rewriter benchmarks independently:

```sh
# Disable all rewritten-query runs.
./batch_run.sh --no-rewriter

# Start with DSB, but skip its SPJ rewrite benchmark.
./batch_run.sh --rewriter=dsb --skip-rewriter=dsb_spj

# Opt in to every committed rewrite artifact.
./batch_run.sh --rewriter=all
```

`--rewriter` accepts `none`, `all`, `dsb`, or a comma-separated combination of
`graph`, `lsqb`, `dsb_agg`, `dsb_spj`, and `tpch`. `--skip-rewriter` removes
suites from that selection. The equivalent environment controls are
`YANPLUS_REWRITER_SUITES` and `YANPLUS_REWRITER_SKIP`, using space-separated
values. Command-line options override them. Rewriter runs only for suites also
selected on the `batch_run.sh` command line. Non-DSB rewrite directories are
opt-in research artifacts; some contain alternative decompositions or depend
on externally created views. The runner executes them verbatim and stops
loudly on invalid SQL or a missing dependency.

The default run order is `origin yanplus`. For a second counterbalanced pass,
use `YANPLUS_VARIANT_ORDER="yanplus origin"`; the selected order is printed in
the batch metadata. Rewriter runs after those compiled variants for each
enabled suite.

For one suite and one variant, call the underlying launcher directly:

```sh
./auto_run.sh lsqb lsqb origin 64 0-15,24-71 5
./auto_run.sh lsqb lsqb yanplus 64 0-15,24-71 5
./auto_run.sh dsb dsb_agg_rewrite rewriter 64 0-15,24-71 5
```

All modes receive the same taskset mask, thread count, warm-up, and timed
repetitions. Results are written beside each query as
`log_<query>_<variant>.txt` and `time_<query>_<variant>.txt`. The parameterized
LSQB BI templates use documented, overridable defaults:
`LSQB_COUNTRY=China`, `LSQB_TAG_CLASS=Song`,
`LSQB_START_DATE=2012-08-29`, and `LSQB_END_DATE=2012-11-24`.

`taskset` is Linux-only and the values are logical CPU IDs. Check the target
host layout with `lscpu -e=CPU,CORE,SOCKET,NODE` before using this machine-specific
mask.

- Sub-Graph Pattern Benchmark (SGPB) 

- LSQB 

- TPC-H & Decision Support Benchmark (DSB)

- Join Order Benchmark (JOB)


> Below is the original DuckDB's README.


---

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="logo/DuckDB_Logo-horizontal.svg">
    <source media="(prefers-color-scheme: dark)" srcset="logo/DuckDB_Logo-horizontal-dark-mode.svg">
    <img alt="DuckDB logo" src="logo/DuckDB_Logo-horizontal.svg" height="100">
  </picture>
</div>
<br>

<p align="center">
  <a href="https://github.com/duckdb/duckdb/actions"><img src="https://github.com/duckdb/duckdb/actions/workflows/Main.yml/badge.svg?branch=main" alt="Github Actions Badge"></a>
  <a href="https://discord.gg/tcvwpjfnZx"><img src="https://shields.io/discord/909674491309850675" alt="discord" /></a>
  <a href="https://github.com/duckdb/duckdb/releases/"><img src="https://img.shields.io/github/v/release/duckdb/duckdb?color=brightgreen&display_name=tag&logo=duckdb&logoColor=white" alt="Latest Release"></a>
</p>

## DuckDB

DuckDB is a high-performance analytical database system. It is designed to be fast, reliable, portable, and easy to use. DuckDB provides a rich SQL dialect with support far beyond basic SQL. DuckDB supports arbitrary and nested correlated subqueries, window functions, collations, complex types (arrays, structs, maps), and [several extensions designed to make SQL easier to use](https://duckdb.org/docs/stable/sql/dialect/friendly_sql.html).

DuckDB is available as a [standalone CLI application](https://duckdb.org/docs/stable/clients/cli/overview) and has clients for [Python](https://duckdb.org/docs/stable/clients/python/overview), [R](https://duckdb.org/docs/stable/clients/r), [Java](https://duckdb.org/docs/stable/clients/java), [Wasm](https://duckdb.org/docs/stable/clients/wasm/overview), etc., with deep integrations with packages such as [pandas](https://duckdb.org/docs/guides/python/sql_on_pandas) and [dplyr](https://duckdb.org/docs/stable/clients/r#duckplyr-dplyr-api).

For more information on using DuckDB, please refer to the [DuckDB documentation](https://duckdb.org/docs/stable/).

## Installation

If you want to install DuckDB, please see [our installation page](https://duckdb.org/docs/installation/) for instructions.

## Data Import

For CSV files and Parquet files, data import is as simple as referencing the file in the FROM clause:

```sql
SELECT * FROM 'myfile.csv';
SELECT * FROM 'myfile.parquet';
```

Refer to our [Data Import](https://duckdb.org/docs/stable/data/overview) section for more information.

## SQL Reference

The documentation contains a [SQL introduction and reference](https://duckdb.org/docs/stable/sql/introduction).

## Development

For development, DuckDB requires [CMake](https://cmake.org), Python 3 and a `C++11` compliant compiler. In the root directory, run `make` to compile the sources. For development, use `make debug` to build a non-optimized debug version. You should run `make unit` and `make allunit` to verify that your version works properly after making changes. To test performance, you can run `BUILD_BENCHMARK=1 BUILD_TPCH=1 make` and then perform several standard benchmarks from the root directory by executing `./build/release/benchmark/benchmark_runner`. The details of benchmarks are in our [Benchmark Guide](benchmark/README.md).

Please also refer to our [Build Guide](https://duckdb.org/docs/stable/dev/building/overview) and [Contribution Guide](CONTRIBUTING.md).

## Support

See the [Support Options](https://duckdblabs.com/support/) page and the dedicated [`endoflife.date`](https://endoflife.date/duckdb) page.
