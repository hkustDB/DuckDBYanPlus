# Yan+ semi-join filter comparison

This experiment executes six deterministic Yan+ workloads over identical
generated tables and the same DuckDB v1.5 plans. Within every workload pair,
the only functional change is `yanplus_semijoin_filter`: `BLOOM` (the default)
versus exact `HASH`.

| Workload | Shape and filter keys | Expected filter pairs | Purpose |
|---|---|---:|---|
| `cyclic_triangle` | Three-relation cycle, two-integer composite separator | 1 | Small plan-derived GHD baseline |
| `acyclic_chain` | Four-relation chain, single `BIGINT` keys | 3 | Cascading selectivity and inline exact-Hash storage |
| `acyclic_skewed_star` | Fact plus three filtered dimensions, single `INTEGER` keys | 3 | Fan-in and stacked filters over a skewed fact table |
| `cyclic_four_cycle` | Four-relation cyclic core plus an acyclic tail | 1 | Larger GHD boundary and boundary descent |
| `cyclic_wide_composite` | Large cycle, `VARCHAR` + `BIGINT` separator | 1 | Boxed exact-Hash keys and parallel Bloom construction |
| `cyclic_skew_duplicates` | Duplicate-heavy cycle, integer composite separator | 1 | Exact-Hash deduplication versus Bloom false positives |

The wide-composite build contains 1.2 million rows, above the 1,048,576-row
threshold where Bloom construction can finalize in parallel. Exact Hash
finalization remains serial. The duplicate-skew build contains two million rows
but only 65,536 distinct composite keys. Together with the smaller scalar-key
chain and star, these cases prevent one key representation or selectivity from
dominating the comparison.

The acyclic chain and star remain projected `SELECT` queries so they exercise
predicate-transfer insertion; changing them to `count(*)` would select the
acyclic aggregate-pushdown path instead. The four-cycle and two largest cyclic
cases use `count(*)` to avoid result materialization dominating their filter
comparison. Only within-workload Bloom-versus-Hash and single-versus-multi
ratios should be interpreted as controlled comparisons.

The count-based four-cycle, wide-composite, and duplicate-skew definitions also
embed their expected results (`62,500`, `24,000`, and `2,000,000`). The
benchmark runner reports `INCORRECT` instead of recording a timing if either
backend changes a result.

Every workload uses this four-case matrix:

- Single-thread Bloom and Hash: one DuckDB thread fixed to logical CPU `0`.
- Multi-thread Bloom and Hash: 64 DuckDB threads fixed to logical CPUs
  `0-31,36-67`.
- Logical CPUs `32-35` and `68-71` are excluded from every multi-thread
  process.

Both backends use exactly the same CPU affinity within each profile. The
single-thread CPU must also belong to the multi-thread CPU mask.

DuckDB v1.5 automatically pins workers on hosts with more than 64 CPUs. This
implementation maps that pinning onto the inherited affinity mask, so
automatic startup pinning cannot select CPUs outside that mask. The benchmark
runner's `--threads` option is the single source of truth for its worker count.

Build and run all six workloads from the repository root:

```sh
BUILD_BENCHMARK=1 make release
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --output benchmark/yanplus/results.csv
```

The comparison script requires Linux `taskset` from `util-linux`. It validates
that the single-thread mask exposes exactly one CPU and that the multi-thread
mask exposes exactly as many CPUs as DuckDB threads. To deliberately use
another fixed configuration, change the values together, for example:

```sh
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --single-cpu 4 \
  --multi-threads 32 \
  --multi-cpu-list 4-35
```

List or select workloads without changing the CPU policy:

```sh
python3 benchmark/yanplus/compare_semijoin_filters.py --list-workloads

# Four rows: Bloom/Hash under single-thread and multi-thread execution.
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --workload cyclic_wide_composite \
  --output benchmark/yanplus/wide_results.csv

# Workload selection is repeatable and also accepts comma-separated names.
python3 benchmark/yanplus/compare_semijoin_filters.py \
  --runner build/release/benchmark/benchmark_runner \
  --workload acyclic_chain,acyclic_skewed_star
```

`--threads` and `--cpu-list` remain aliases for `--multi-threads` and
`--multi-cpu-list`. The benchmark runner performs one warm-up and five measured
executions for every workload/profile/backend case. The default CSV therefore
contains 24 rows. Before timing, the script verifies pairwise that the Bloom and
Hash benchmark definitions and interpreted query text match outside the backend
setting and descriptive metadata. It randomizes workload/profile blocks while
keeping the two backends adjacent within a block.

Each CSV row records workload description, topology, key shape, expected filter
pair count, benchmark path, thread count, CPU mask, median, p95, minimum,
maximum, speedup relative to Bloom in the same workload/profile, and speedup
relative to the same backend's single-thread median. Use the SQL regression
tests under `test/sql/optimizer` for result-equivalence and NULL/composite-key
correctness. In particular,
[`test_yanplus_semijoin_filter_workloads.test`](../../test/sql/optimizer/plan/test_yanplus_semijoin_filter_workloads.test)
guards the three-pair chain and star plans plus the plan-derived cyclic-bag
boundary. Benchmark timings are intentionally not asserted in CI.
