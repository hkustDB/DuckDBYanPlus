# Yan+ semi-join filter comparison

This experiment executes one cyclic triangle query over identical generated
tables and the same DuckDB v1.5 join plan. The only changed setting is
`yanplus_semijoin_filter`: `BLOOM` (the default) versus exact `HASH`.

Build and run it from the repository root:

```sh
BUILD_BENCHMARK=1 GEN=ninja make release
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --output benchmark/yanplus/results.csv
```

The benchmark runner performs one warm-up and five measured executions for
each backend. The comparison script checks that both benchmark definitions
return the same query text, randomizes backend order, and reports median, p95,
minimum, maximum, and speedup relative to Bloom. Use the SQL regression tests
under `test/sql/optimizer` for result-equivalence and NULL/composite-key
correctness; benchmark timings are intentionally not asserted in CI.
