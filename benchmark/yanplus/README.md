# Yan+ semi-join filter comparison

This experiment executes one cyclic triangle query over identical generated
tables and the same DuckDB v1.5 join plan. The only changed setting is
`yanplus_semijoin_filter`: `BLOOM` (the default) versus exact `HASH`.

The default machine policy is:

- 64 DuckDB threads.
- Logical CPUs `0-63` through Linux `taskset`.
- Logical CPUs `64-71` excluded from the DuckDB processes.

DuckDB v1.5 automatically pins workers on hosts with more than 64 CPUs. This
implementation maps that pinning onto the inherited affinity mask, so
automatic startup pinning cannot select CPUs 64–71. The benchmark
runner's `--threads` option is the single source of truth for its worker count.

Build and run it from the repository root:

```sh
BUILD_BENCHMARK=1 GEN=ninja make release
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --output benchmark/yanplus/results.csv
```

The comparison script requires Linux `taskset` from `util-linux` and validates
that the CPU list exposes exactly 64 CPUs. To deliberately use another
configuration, change both values together, for example:

```sh
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --threads 32 \
  --cpu-list 0-31
```

The benchmark runner performs one warm-up and five measured executions for
each backend. The comparison script checks that both benchmark definitions
return the same query text, randomizes backend order, and reports median, p95,
minimum, maximum, and speedup relative to Bloom. Use the SQL regression tests
under `test/sql/optimizer` for result-equivalence and NULL/composite-key
correctness; benchmark timings are intentionally not asserted in CI.
