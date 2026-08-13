# Yan+ semi-join filter comparison

The primary comparison uses the requested real Graph and LSQB queries,
including predicate-selectivity sweeps for Graph Q1 and LSQB Q5. It runs each
query with one fixed execution configuration and changes only
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

### Graph Q1 predicate-selectivity sweep

The `graph_q1_sweep` group keeps Graph Q1's original `g1.src < 1000`
predicate and adds a modulo predicate to it. Thus, percentages below are
relative to the original Q1 input population, not the entire `Graph` table:

| Runner name | Additional predicate | Expected Q1 rows retained |
|---|---|---:|
| `graph_q1` | none | 100% |
| `graph_q1_predicate_50pct` | `g1.src % 2 = 0` | 50% |
| `graph_q1_predicate_20pct` | `g1.src % 5 = 0` | 20% |
| `graph_q1_predicate_10pct` | `g1.src % 10 = 0` | 10% |
| `graph_q1_predicate_05pct` | `g1.src % 20 = 0` | 5% |
| `graph_q1_predicate_02pct` | `g1.src % 50 = 0` | 2% |
| `graph_q1_predicate_01pct` | `g1.src % 100 = 0` | 1% |

The expected percentages assume `g1.src` values/edge frequencies are
reasonably uniform modulo each divisor. Keeping `< 1000` ensures no sweep point
is deliberately larger than the original long-running Graph Q1. Modulo also
keeps surviving keys spread across the original source-ID range, preventing the
min/max dynamic filter shared by both backends from replacing the membership
test.

Run only the Graph Q1 sweep with:

```sh
python3 benchmark/yanplus/run_query_filter_comparison.py \
  --query graph_q1_sweep \
  --repetitions 5 \
  --output graph_q1_predicate_sweep.csv
```

### Q5 predicate-selectivity sweep

The `q5_sweep` query group is designed to expose the backend cost instead of
letting the final join/result dominate the measurement. Every member uses the
same LSQB Q5 join graph and adds a deterministic predicate to the relation that
creates the semi-join filter:

| Runner name | Added predicate | Expected retained rows |
|---|---|---:|
| `q5_predicate_50pct` | `MessageId % 2 = 0` | 50% |
| `q5_predicate_20pct` | `MessageId % 5 = 0` | 20% |
| `q5_predicate` | `MessageId % 10 = 0` | 10% |
| `q5_predicate_05pct` | `MessageId % 20 = 0` | 5% |
| `q5_predicate_02pct` | `MessageId % 50 = 0` | 2% |
| `q5_predicate_01pct` | `MessageId % 100 = 0` | 1% |

The percentages assume message IDs are reasonably uniform modulo the divisor.
This is a selectivity sweep rather than six unrelated queries: only the divisor
changes. Modulo retains keys across the full ID domain, preventing the min/max
dynamic filter shared by both backends from replacing the membership test.
Lower retained fractions reduce the downstream join and `COPY` work, so
Bloom/Hash construction and probing become a larger part of elapsed time.
At 64 threads, builds containing at least 1,048,576 materialized rows also
exercise the implementation's parallel Bloom finalization, while exact Hash
finalization remains single-threaded. The most useful points are therefore the
selective predicates whose filtered build still exceeds that row threshold.

Run only this experiment with:

```sh
python3 benchmark/yanplus/run_query_filter_comparison.py \
  --query q5_sweep \
  --repetitions 9 \
  --output q5_predicate_sweep.csv
```

Nine repetitions are recommended for the shorter selective queries. Plot
`expected_selectivity_pct` against `bloom_speedup_vs_hash`; values greater than
`1.0` mean Bloom is faster.

The two LSQB files are projection-only variants of
[`lsqb/q1.sql`](../../lsqb/q1.sql) and [`lsqb/q5.sql`](../../lsqb/q5.sql): the
leading `SELECT count(*)` is replaced by `SELECT *`, and every remaining byte of
SQL is unchanged. The runner checks this before every experiment and fails if a
variant has drifted from its source.

`q1_predicate` adds the unary predicate `Person.PersonId % 10 = 0`, while
`q5_predicate` adds `Message_hasTag_Tag_T.MessageId % 10 = 0`. The modulo
conditions select a deterministic tenth of the main entity IDs without relying
on scale-factor-specific ID ranges. The runner also verifies these and all
predicate-sweep files against their source query and expected predicate before
executing them.

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
python3 benchmark/yanplus/run_query_filter_comparison.py --query graph_q1_sweep
python3 benchmark/yanplus/run_query_filter_comparison.py --query q5_sweep
python3 benchmark/yanplus/run_query_filter_comparison.py --dry-run
```

## Result

For each query/backend pair, the runner performs one untimed warm-up followed
by five measured executions by default. Query blocks and the backend order
inside each block are seeded and randomized. The output CSV has one direct
comparison row per query with predicate metadata, Bloom and Hash median, p95,
minimum, maximum, raw samples, and the faster backend.
`bloom_speedup_vs_hash` is `hash_time / bloom_time`, so values greater than
`1.0` mean Bloom was faster. The reciprocal legacy column
`hash_speedup_vs_bloom` is retained.

The default output is:

```text
semijoin_comparison_results.csv
```

The older synthetic `.benchmark` fixtures and
`compare_semijoin_filters.py` remain available for targeted implementation
experiments, but the real-query runner does not load or execute them.
