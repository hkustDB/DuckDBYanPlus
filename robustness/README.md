# Yannakakis plan robustness experiment

This experiment compares every selected upstream `rewriteN.sql` plan with the
matching original query executed by the unmodified DuckDB build. It includes 46
rewrites for six sampled queries:

| Workload | Query | Rewrites |
| --- | --- | ---: |
| LSQB | q1 | 8 |
| LSQB | q9 | 8 |
| JOB | 2d | 6 |
| JOB | 15d | 8 |
| JOB | 17a | 8 |
| JOB | 22d | 8 |

The SQL comes from the exact commits in `manifest.tsv`. Upstream identifiers can
start at zero or contain gaps, so each complete query set is normalized to the
requested local convention `rewrite1.sql`, `rewrite2.sql`, and so on. The
manifest preserves the original filename, upstream and local SHA-256 values, and
any DuckDB compatibility adaptation. The only SQL adaptation is replacing
MySQL-style backticks around LSQB q1's `Comment` identifier; it matches the
repository's existing DuckDB q1 spelling. The selection deliberately matches
generic upstream `rewrite[0-9]+.sql` files; the separate
`rewriteYa*.sql` family is outside this requested filename set.

## Run

Build the original DuckDB binary and provide populated `lsqb_db` and `job_db`
files. The runner supports Python 3.8 and newer. All experiment parameters have
reproducible defaults, so on the Linux experiment server run:

```sh
python3 robustness/run_experiment.py
```

The defaults are:

| Parameter | Default |
| --- | --- |
| DuckDB binary | `build/duckdb_origin/duckdb` |
| LSQB database | `lsqb_db` |
| JOB database | `job_db` |
| Threads | `64` |
| Linux CPU list | `0-31,36-67` |
| Measured repetitions | `10` |
| Warm-ups per repetition | `1` |
| Randomization seed | `20260822` |
| Per-plan process timeout | `600` seconds (10 minutes) |
| Output | `robustness/results/<UTC timestamp>` |

Command-line options remain available when a machine differs from the experiment
server. Use `--cpu-list none` to disable Linux CPU pinning, for example on macOS.

Each repetition is a globally randomized block containing every valid original
and rewrite plan. Every plan runs in a fresh DuckDB process and receives the
same thread count and number of warm-ups. View declarations are converted to
temporary logical views and created outside the timed interval; because DuckDB
views are lazy, their relational work is still executed by the timed final
query.

Before timing, the runner executes every plan. Rewrites that match a completed
`query.sql` result are marked `ok`. If the original query errors or reaches the
10-minute timeout, successful rewrites are marked `unverified` and are still
timed; they are not represented as exact-result matches. A rewrite mismatch,
rewrite SQL error, or rewrite timeout remains ineligible for timing. An
unverified rewrite or other validation failure keeps the overall experiment
scientifically incomplete even though the available performance measurements
are written.

The timestamped result directory contains:

- `validation.csv`: semantic-equivalence results for every plan.
- `raw_results.csv`: one measured runtime per plan and randomized block.
- `plan_statistics.csv`: mean, median, standard deviation, p05, p95, min, max,
  coefficient of variation, and mean/median speedups against DuckDB.
- `query_summary.csv`: wins and aggregate speedups within each sampled query.
- `robust_query_statistics.csv`: one row per query that has at least one strict
  steady-win rewrite. Its columns, in order, are query, original median (or
  timeout lower bound), pooled rewrite average, pooled rewrite median, fastest
  rewrite run, slowest rewrite run, pooled rewrite standard deviation, and the
  true number of retained rewrite plans.
- `overall_summary.csv`: cross-plan mean, median, geometric mean, tail, and
  all-plans-win statistics.
- `summary.md`: the human-readable conclusion.
- `metadata.json` and `logs/`: reproducibility metadata and raw command output.

The full-set proof criterion is strict: all 46 rewrites must validate, finish
all repetitions, and have a median runtime lower than the corresponding
original. The arithmetic-mean criterion is reported independently. The
summarizer never changes a negative or incomplete result into an all-plans-win
conclusion.

The curated `robust_query_statistics.csv` uses a stronger observed-run filter
for its retained subset. With a measured original, a plan is retained only when
its slowest rewrite run is faster than the original's fastest run. With a timed
out original, `600` seconds is treated only as a censored lower bound and the
rewrite's slowest run must remain below that bound. The CSV records the true
number of retained rewrites; plan identities and exclusions remain available in
the detailed plan statistics and validation outputs. The curated table must not
be described as proof for discarded or semantically unverified plans.

To regenerate a summary from an existing run:

```sh
python3 robustness/summarize.py \
  robustness/results/RUN/raw_results.csv \
  robustness/results/RUN/validation.csv
```

## Verify or reproduce the import

With a checkout of `hkustDB/Yannakakis-Plus` that contains both pinned commits:

```sh
python3 robustness/import_queries.py --check /path/to/Yannakakis-Plus
```

Remove `--check` to reproduce the committed SQL files and manifest.
