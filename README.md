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

Yan+ also supports plain, direct-column `SELECT DISTINCT` over its supported
inner equality-join shape. It retains the root DISTINCT result columns and
pushes smaller partial DISTINCT operators into the join tree, following the
original main-branch implementation. Computed or volatile result expressions,
volatile filters, `DISTINCT ON`, ordered DISTINCT, and unsupported nested query
shapes conservatively retain DuckDB's native optimizer path.

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

The helper defaults to the `Unix Makefiles` generator, so Ninja is not
required. To opt into Ninja, run
`CMAKE_GENERATOR=Ninja ./build_duckdb.sh`.

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
[`benchmark/yanplus/README.md`](benchmark/yanplus/README.md). It covers six
paired workloads: acyclic chain and star plans, three- and four-relation cyclic
plans, a large mixed-type composite separator, and duplicate-heavy skew. Only
the semi-join-filter backend changes within each pair. One invocation measures
both backends under two fixed-affinity profiles: one thread on CPU `0`, and 64
threads on CPUs `0-31,36-67`. The default combined CSV has 24 result rows and
records workload metadata, configuration, thread count, and CPU mask.

On the 72-logical-CPU experiment host, the multi-thread profile and the query
suite launchers use 64 DuckDB threads with Linux
`taskset --cpu-list 0-31,36-67`. Thus logical CPUs 32–35 and 68–71 are excluded.
The query-suite launchers disable internal pinning and rebuild the worker pool
before timing. The v1.5 scheduler also maps automatic startup pinning onto the
inherited allowed-CPU mask instead of global sequential CPU IDs, which keeps
the benchmark runner inside the same mask.

```sh
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --output benchmark/yanplus/results.csv
```

To run the committed Graph, LSQB, DSB, TPC-H, and JOB suites with both compiled
variants, plus the committed DSB rewritten queries:

```sh
./batch_run.sh
```

By default, Yan+ runs every selected query, while origin skips Graph
`q4`, `q5`, and `q7`, plus LSQB `q8` and `q9`. These origin-only exclusions do
not affect Yan+, rewriter, or Yannakakis-only runs. The batch summary reports
the runnable and skipped counts separately.

Rewriter is a SQL-query baseline, not a third DuckDB build. It runs the
committed `*_rewrite` SQL with `build/duckdb_origin/duckdb`. Setup
`CREATE VIEW` statements are made temporary and run outside the timed region;
the final rewritten query receives the same warm-up and timed repetitions as
origin and Yan+. The default rewriter selection is `dsb`, currently six
`dsb_agg_rewrite` queries and five `dsb_spj_rewrite` queries. DSB SPJ query 99
has no committed rewrite, and there is no JOB suite in this existing baseline.
`batch_run.sh` executes these existing rewritten SQL files; it does not generate
new rewritten SQL. Results are written inside each `*_rewrite` directory as
`log_<query>_rewriter.txt` and `time_<query>_rewriter.txt`.

The database files default to the repository root and must be named
`graph_db`, `lsqb_db`, `dsb_db`, `tpch_db`, and `job_db`. Override their
directory with `YANPLUS_DATABASE_ROOT`. A smaller batch can name suites, for
example:

```sh
YANPLUS_REPETITIONS=1 ./batch_run.sh lsqb tpch
```

Select or skip rewriter benchmarks independently:

```sh
# Run only the default DSB aggregate and SPJ rewrites.
./batch_run.sh --rewriter-only

# Run only every selected rewrite artifact, with no origin or Yan+ runs.
./batch_run.sh --rewriter-only --rewriter=all

# Run only the Graph rewrite suite.
./batch_run.sh --rewriter-only --rewriter=graph graph

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
selected on the `batch_run.sh` command line. `--rewriter-only` skips preflight
and execution for both compiled variants and requires only the active rewrite
directories, their databases, and the origin-compatible rewriter binary.
Non-DSB rewrite directories are opt-in research artifacts; some contain
alternative decompositions or depend on externally created views. The runner
executes them verbatim and reports invalid SQL or missing dependencies as
failures.

### Yannakakis-style (`rewriteYa`) baseline

The Yannakakis-style rewrites are a separate, opt-in baseline based on
Quorion's `reproducibility` branch at commit
`3e48996acc152fc1b19c780ab5c0c9f5f6885e33`. An unchanged `rewriteYa*.sql` is
copied only when the local and Quorion originals have the same normalized SQL
tokens. Query-specific DuckDB adaptations and locally simulated fallbacks are
recorded separately rather than weakening that source-match rule. The complete
source paths, normalized hashes, generation method, and decisions are in
[`yannakakis_rewrite_manifest.tsv`](yannakakis_rewrite_manifest.tsv).

Graph, LSQB, TPC-H, and JOB have dedicated `*_yannakakis_rewrite` directories.
JOB is generated from the local `job_agg` queries using DuckDB semantics. A
literal replacement of `MIN(value)` with `SUM(value)` is not valid because most
JOB payload values are `VARCHAR`. Instead, each JOB artifact performs an
upward and downward `EXISTS` semijoin pass, preserves base-row multiplicity,
then executes the local grouping columns with `SUM(1) AS record_count` over the
reduced relations. Every original predicate is retained in the final join, so
the rewrite has the same bag semantics as `job_agg`. Cyclic alias graphs use a
deterministic spanning-tree reduction; non-tree predicates remain in the final
join, making this a safe partial, Yannakakis-style reduction rather than a claim
of complete cyclic reduction.

Quorion's 282 JOB `rewriteYa` filenames define the generated variant set. JOB
1a has no upstream `rewriteYa`, so one local DuckDB fallback is generated. This
gives 283 nonempty JOB artifacts and at least one rewrite for every one of the
113 JOB queries. Generated SQL uses the local aliases, which removes upstream
differences such as `character` versus `character1`. JOB timings therefore
compare directly with `job_agg` and the normal JOB origin/Yan+ runs.

Coverage is complete for all four suites:

- Graph has six locally simulated two-pass reducers. Its copied cyclic q4 bag
  plan is retained, with an empty-input fix so its annotation sum agrees with
  `COUNT(*)`.
- LSQB q4/q5/q7/q8 adapt the corresponding Quorion relation names to the local
  `_T` schema. Cyclic q2 is represented as one GHD bag: there is no inter-bag
  semijoin, and DuckDB executes the exact join inside that bag. BI-3 and BI-9
  use local two-pass reducers; BI-3 retains the tag branch as `EXISTS`, and
  BI-9 treats the grouped MPP CTE as one relation.
- TPC-H q5/q10 use the local DuckDB date expressions, q5 repairs the two pinned
  source projections that omitted the revenue column, and q16 restores the
  local `NOT IN` supplier predicate with DuckDB NULL semantics. Q7 and q18 now
  create their `lineitemwithyear` and `q18_inner` helpers inside each artifact.
- Quorion annotation-based LSQB and Graph counts use
  `COALESCE(SUM(annot), 0)`, matching DuckDB `COUNT(*)` on empty input.

The current import contains 318 runnable artifacts for 137 originals and no
blank placeholders. A simulated cyclic one-bag plan is an experiment-complete
GHD fallback, not a claim that the importer enumerates or optimizes all GHDs.

Run only this baseline with the origin-compatible binary:

```sh
# Run every runnable Graph, LSQB, TPC-H, and JOB rewriteYa artifact.
./batch_run.sh --yannakakis-only

# Run only JOB rewriteYa artifacts.
./batch_run.sh --yannakakis-only --yannakakis=job job

# Run the matching JOB SUM originals separately for a direct comparison.
./auto_run.sh job job_agg origin 64 0-31,36-67 3

# Run every supported rewriteYa suite except JOB.
./batch_run.sh --yannakakis-only --skip-yannakakis=job
```

`--yannakakis` accepts `none`, `all`, `graph`, `lsqb`, `tpch`, `job`, or a
comma-separated combination. The equivalent environment controls are
`YANPLUS_YANNAKAKIS_SUITES` (default `all`) and
`YANPLUS_YANNAKAKIS_SKIP`. `--yannakakis-only` and `--rewriter-only` are
mutually exclusive; a normal `batch_run.sh` invocation remains unchanged and
does not run this opt-in baseline. Results use the distinct
`log_<artifact>_yannakakis.txt` and `time_<artifact>_yannakakis.txt` names.

To reproduce or verify the import against a checkout of the pinned Quorion
commit:

```sh
python3 scripts/import_yannakakis_rewrites.py /path/to/Quorion
python3 scripts/import_yannakakis_rewrites.py --check /path/to/Quorion

# Check per-query coverage, nonempty artifacts, and manifest consistency.
python3 scripts/validate_yannakakis_coverage.py

# Bind and EXPLAIN all JOB artifacts against an empty DuckDB JOB schema.
python3 scripts/validate_job_yannakakis.py \
    --duckdb build/duckdb_origin/duckdb

# On the experiment machine, compare every result with job_agg using
# bidirectional DuckDB EXCEPT ALL.
python3 scripts/validate_job_yannakakis.py \
    --duckdb build/duckdb_origin/duckdb --database ./job_db
```

Override the origin-only skip list with one or more `--skip-origin` options:

```sh
# Use a custom origin-only skip list.
./batch_run.sh --skip-origin=graph:q4,q5,q7 --skip-origin=lsqb:q8,q9

# Disable origin skipping and run every selected query with both variants.
./batch_run.sh --no-origin-skip
```

The first `--skip-origin` option replaces the defaults and later occurrences
append to it. Query names are exact SQL filename stems. The equivalent
environment setting uses space-separated suite groups:

```sh
YANPLUS_ORIGIN_SKIP='graph:q4,q5,q7 lsqb:q8,q9' ./batch_run.sh
```

Set `YANPLUS_ORIGIN_SKIP=none` to disable the defaults through the environment.
Only skip entries belonging to selected suites are applied. Every active entry
is validated before the batch starts.

The default run order is `origin yanplus`. For a second counterbalanced pass,
use `YANPLUS_VARIANT_ORDER="yanplus origin"`; the selected order is printed in
the batch metadata. Rewriter runs after those compiled variants for each
enabled suite.

For one suite and one variant, call the underlying launcher directly:

```sh
./auto_run.sh lsqb lsqb origin 64 0-31,36-67 3
./auto_run.sh lsqb lsqb yanplus 64 0-31,36-67 3
./auto_run.sh dsb dsb_agg_rewrite rewriter 64 0-31,36-67 3
./auto_run.sh lsqb lsqb_yannakakis_rewrite yannakakis 64 0-31,36-67 3
```

For a direct origin run, pass query basenames for that one query directory:

```sh
YANPLUS_ORIGIN_SKIP_QUERIES=q4,q5,q7 ./auto_run.sh graph graph origin 64 0-31,36-67 3
YANPLUS_ORIGIN_SKIP='graph:q4,q5,q7 lsqb:q8,q9' ./batch_run.sh
```

`YANPLUS_ORIGIN_SKIP_QUERIES` accepts comma- or space-separated names and
is ignored for Yan+ and rewriter. When an origin query is skipped, its exact
`log_<query>_origin.txt` and `time_<query>_origin.txt` files are removed so an
older result cannot be mistaken for a result from the current batch.

All modes receive the same taskset mask, thread count, warm-up, and timed
repetitions. Results are written beside each query as
`log_<query>_<variant>.txt` and `time_<query>_<variant>.txt`. The parameterized
LSQB BI templates use documented, overridable defaults:
`LSQB_COUNTRY=China`, `LSQB_TAG_CLASS=Song`,
`LSQB_START_DATE=2012-08-29`, and `LSQB_END_DATE=2012-11-24`.

A query failure stops only that query's remaining repetitions. The runners
record its stage and original exit status in the log, omit its final timing
file, and continue with the remaining queries, variants, suites, and rewriter
runs. After attempting everything, they print a failure summary and return a
nonzero status if any query failed. Timing files are published atomically only
after all repetitions for that query succeed, so partial or stale timings are
not reported as valid results.

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
