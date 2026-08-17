# Yan+ semi-join filter comparison

The comparison has two complementary experiments:

1. The LSQB Q5 sweep measures complete query runtime with the production Yan+
   Bloom and exact-Hash backends.
2. A single-filter microbenchmark isolates initialization, build, and probe
   costs while deliberately crossing L1d, L2, and L3 capacity.

Graph Q1 and the unrelated Q1 cases are not part of this experiment.

## LSQB Q5 query sweep

Every point uses the LSQB Q5 join graph and changes only a deterministic
predicate on the relation that creates the semi-join filter. The plotting
script sorts the points by retained fraction and gives them stable short names:

| Figure name | Runner name | Added predicate | Expected rows retained |
|---|---|---|---:|
| `q5_v1` | `lsqb_q5` | none | 100% |
| `q5_v2` | `q5_predicate_50pct` | `MessageId % 2 = 0` | 50% |
| `q5_v3` | `q5_predicate_20pct` | `MessageId % 5 = 0` | 20% |
| `q5_v4` | `q5_predicate` | `MessageId % 10 = 0` | 10% |
| `q5_v5` | `q5_predicate_05pct` | `MessageId % 20 = 0` | 5% |
| `q5_v6` | `q5_predicate_02pct` | `MessageId % 50 = 0` | 2% |
| `q5_v7` | `q5_predicate_01pct` | `MessageId % 100 = 0` | 1% |

The percentages assume message IDs are reasonably uniform modulo each divisor.
Modulo retains keys across the full ID domain, so the shared min/max dynamic
filter cannot replace the membership filter. Each projected query is checked
against [`lsqb/q5.sql`](../../lsqb/q5.sql), then wrapped in
`COPY (...) TO '/dev/null' (FORMAT CSV)` to execute and consume the full result
without terminal rendering or result-file I/O.

Both implementations run the same SQL under the same thread and CPU-affinity
configuration; only this setting changes:

```sql
SET yanplus_semijoin_filter = 'BLOOM';
-- or
SET yanplus_semijoin_filter = 'HASH';
```

Build Yan+ and place `lsqb_db` in the repository root, then run:

```sh
./build_duckdb.sh
python3 benchmark/yanplus/run_query_filter_comparison.py \
  --query q5_sweep \
  --repetitions 9 \
  --output semijoin_comparison_results.csv
```

The server defaults are 64 DuckDB threads pinned with Linux `taskset` to
logical CPUs `0-31,36-67`. Change the thread count and affinity mask together.
Use `--database-root` when `lsqb_db` is elsewhere, `--list-queries` to inspect
the seven registered Q5 cases, and `--dry-run` to validate and print their SQL.

The CSV contains Bloom/Hash median, p95, minimum, maximum, raw samples, and the
faster backend. `bloom_speedup_vs_hash` is `hash_time / bloom_time`, so values
greater than 1 mean Bloom is faster.

## Filter memory assumptions

The cache experiment uses one unique `uint64_t` key per build row. That selects
the production Hash filter's compact inline representation and gives both
filters an exact, reproducible allocation model.

| Backend | Final allocated filter bytes | Interpretation |
|---|---|---|
| Bloom | `64 + min(NextPowerOfTwo(max(512, 12R)) / 8, 512 MiB)` | `R` is materialized build rows. The 64 bytes are the alignment allowance. Power-of-two rounding gives about 1.5–3 bytes per row before the cap. The filter sets four bits per hash and can return false positives. |
| Hash | `1024 + 16C + C/8`, where `C` starts at 64, is a power of two, and `N <= 0.75C` | `N` is distinct non-null keys. Each inline slot stores an 8-byte hash and 8-byte key; the occupancy bitmap costs one bit per slot. The retained 1 KiB is the constructor's boxed-table allocation. This is about 21.5–43 bytes per key across a resize cycle and is exact. |

These numbers exclude vector-object headers, allocator metadata, input columns,
and the generated probe stream. `filter_bytes` is the final allocation, while
`peak_build_bytes` also records the temporary old-plus-new Hash tables during a
resize. Composite or variable-width Hash keys use boxed `Value` tuples and need
more memory; the microbenchmark intentionally excludes them so it measures one
well-defined layout.

Bloom sizes from build rows, whereas Hash sizes from distinct keys. They are
equal in this microbenchmark because all generated build keys are unique. Do
not apply that equality to a duplicate-heavy query.

## Cache-boundary microbenchmark

The summary form of `lscpu` reports cache `ALL-SIZE`, summed across cache
instances. Therefore these server values:

```text
L1d 1.7 MiB, L1i 1.1 MiB, L2 45 MiB, L3 78 MiB
```

must not be used directly as the boundaries of one pinned worker. If the host
has 36 private L1/L2 instances and two L3 instances, they suggest roughly
48 KiB L1d per core, 1.25 MiB L2 per core, and 39 MiB L3 per socket; this is an
inference and must be verified. Inspect `ONE-SIZE` and topology with:

```sh
lscpu -C
lscpu -e=CPU,CORE,SOCKET,NODE,CACHE
```

The runner reads the selected CPU's per-instance sizes from Linux sysfs, so the
default experiment does not depend on rounded aggregate values:

```sh
python3 benchmark/yanplus/run_filter_cache_microbenchmark.py \
  --cpu 0 \
  --output semijoin_cache_results.csv
```

Use `--dry-run` first to print every chosen allocation and cardinality without
compiling or timing. If sysfs is unavailable, pass only verified `ONE-SIZE`
values—not the aggregate totals—for example:

```sh
python3 benchmark/yanplus/run_filter_cache_microbenchmark.py \
  --cpu 0 \
  --cache-sizes-mib 0.046875 1.25 39 \
  --output semijoin_cache_results.csv
```

For those illustrative per-instance sizes, `--dry-run` selects the following
mid-allocation points. The actual server run uses the detected values instead:

| Boundary | Bloom below → above | Hash below → above |
|---|---|---|
| L1d, 48 KiB | 16,384 keys / 0.031 MiB → 32,768 / 0.063 MiB | 1,152 keys / 0.032 MiB → 2,304 / 0.064 MiB |
| L2, 1.25 MiB | 524,288 / 1.000 MiB → 1,048,576 / 2.000 MiB | 36,864 / 1.009 MiB → 73,728 / 2.017 MiB |
| L3, 39 MiB | 16,777,216 / 32.000 MiB → 33,554,432 / 64.000 MiB | 1,179,648 / 32.251 MiB → 2,359,296 / 64.501 MiB |

The standalone C++ kernel mirrors the production Bloom sizing/bit operations
and the inline Hash layout/load policy, but uses one deterministic SplitMix-style
hash instead of DuckDB's vector executor. It is a cache/layout microbenchmark,
not a replacement for the complete Q5 timing. For each backend it chooses a
representative allocation step immediately below and above L1d, L2, and L3.
The point lies midway through its allocation step, keeping relative occupancy
comparable instead of contrasting a full table with a newly doubled table.
Duplicate allocations shared by adjacent boundaries are run once.

Each process is pinned to one logical CPU and performs:

- one untimed warm-up and nine measured repetitions;
- unique deterministic build keys generated on demand;
- 20 million random probes per point with a deterministic 50% hit rate;
- separate initialization, insertion, complete-build, and probe timings;
- final and peak filter bytes, generated/observed hit rates, and false-positive rate.

Probe count is fixed across sizes, so a rise in `probe_ns_per_key` reflects a
latency change rather than simply doing more probe operations. Build time can
also jump because Bloom zero-fills a larger allocation and Hash resizes and
rehashes; a build spike alone is not evidence of a cache miss. Use probe-only
time as the primary cache signal. A cache knee is expected but is not
guaranteed to be dramatic because prefetching, TLB behavior, CPU frequency,
NUMA placement, and memory-level parallelism can smooth it. Hardware cache-miss
counters from `perf stat` are the strongest confirmation on the server.

## Draw the figures

Draw the Q5 whole-query comparison:

```sh
python3 scripts/plot_semijoin_comparison.py \
  --input semijoin_comparison_results.csv
```

Draw the cache/memory experiment after running it on the server:

```sh
python3 scripts/plot_semijoin_cache.py \
  --input semijoin_cache_results.csv
```

Both plotting commands default to PNG and PDF under
`figures/duckdb_v1_5/`. The cache figure is
`semijoin_cache_boundary.{png,pdf}` and contains aligned panels for allocated
memory, build nanoseconds per key, and probe nanoseconds per key. All panels
show the detected per-instance L1d/L2/L3 boundaries.

The older synthetic `.benchmark` fixtures and
`compare_semijoin_filters.py` remain available for targeted optimizer/operator
regression experiments; they are not inputs to the Q5 or cache-boundary plots.
