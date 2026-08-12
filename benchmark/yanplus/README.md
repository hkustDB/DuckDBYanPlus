# Yan+ semi-join filter comparison

The primary comparison uses the requested real Graph and LSQB queries,
including unary-predicate versions of LSQB Q1 and Q5. It runs each query with
one fixed execution configuration and changes only
`yanplus_semijoin_filter`:

- `BLOOM`: the default approximate semi-join filter.
- `HASH`: the exact hash-set semi-join filter.

There is no synthetic data generation and no single-thread versus multi-thread
matrix in this runner.

## Queries

| Runner name | SQL | Database |
|---|---|---|
| `graph_q1` | [`graph/q1.sql`](../../graph/q1.sql) unchanged | `graph_db` |
| `lsqb_q1` | [`queries/lsqb_q1_select_all.sql`](queries/lsqb_q1_select_all.sql) | `lsqb_db` |
| `q1_predicate` | [`queries/q1_predicate.sql`](queries/q1_predicate.sql) | `lsqb_db` |
| `lsqb_q5` | [`queries/lsqb_q5_select_all.sql`](queries/lsqb_q5_select_all.sql) | `lsqb_db` |
| `q5_predicate` | [`queries/q5_predicate.sql`](queries/q5_predicate.sql) | `lsqb_db` |

The two LSQB files are projection-only variants of
[`lsqb/q1.sql`](../../lsqb/q1.sql) and [`lsqb/q5.sql`](../../lsqb/q5.sql): the
leading `SELECT count(*)` is replaced by `SELECT *`, and every remaining byte of
SQL is unchanged. The runner checks this before every experiment and fails if a
variant has drifted from its source.

`q1_predicate` adds the unary predicate `Person.PersonId % 10 = 0`, while
`q5_predicate` adds `Message_hasTag_Tag_T.MessageId % 10 = 0`. The modulo
conditions select a deterministic tenth of the main entity IDs without relying
on scale-factor-specific ID ranges. The runner also verifies these files against
their source queries and expected predicates before executing them.

The timed statement wraps each projected query in
`COPY (...) TO '/dev/null' (FORMAT CSV)`. This executes and consumes the full
`SELECT *` result without terminal rendering or result-file I/O. Both filter
settings run exactly the same wrapped SQL.

## Run

Build the Yan+ CLI and place `graph_db` and `lsqb_db` in the repository root:

```sh
./build_duckdb.sh
python3 benchmark/yanplus/run_query_filter_comparison.py
```

If the databases live elsewhere:

```sh
python3 benchmark/yanplus/run_query_filter_comparison.py \
  --database-root /data/yanplus
```

The reproducible host defaults are 64 DuckDB threads pinned with Linux
`taskset` to logical CPUs `0-31,36-67`. A different fixed configuration must
change the thread count and affinity mask together:

```sh
python3 benchmark/yanplus/run_query_filter_comparison.py \
  --threads 32 \
  --cpu-list 4-35
```

`--no-affinity` is available for local development and smoke tests on non-Linux
systems. Do not mix affinity and non-affinity results in the same comparison.

Select a subset or inspect the exact SQL without opening a database:

```sh
python3 benchmark/yanplus/run_query_filter_comparison.py --list-queries
python3 benchmark/yanplus/run_query_filter_comparison.py --query graph_q1,lsqb_q5
python3 benchmark/yanplus/run_query_filter_comparison.py --dry-run
```

## Result

For each query/backend pair, the runner performs one untimed warm-up followed
by five measured executions by default. Query blocks and the backend order
inside each block are seeded and randomized. The output CSV has one direct
comparison row per query with Bloom and Hash median, p95, minimum, maximum, raw
samples, the faster backend, and `hash_speedup_vs_bloom`. A speedup greater than
`1.0` means exact Hash was faster; a value below `1.0` means Bloom was faster.

The default output is:

```text
semijoin_comparison_results.csv
```

The older synthetic `.benchmark` fixtures and
`compare_semijoin_filters.py` remain available for targeted implementation
experiments, but the real-query runner does not load or execute them.
