# Required Yan+/Yannakakis retests

`run_required_retests.sh` packages the timings requested for Graph, LSQB, TPC-H,
DSB, and JOB. It uses the origin binary for original and
SQL-rewrite plans, the Yan+ binary for integrated plans, a fresh DuckDB process
for every sample, and randomized query/mode order. The median of three paired
runs is the primary integrated comparison; minima are recorded for diagnosing
machine noise but are not used to claim a win.

## Prerequisites

Build both binaries and place the databases together:

```bash
./build_duckdb.sh
```

The default database root is the repository and must contain `graph_db`,
`lsqb_db`, `tpch_db`, `dsb_db`, and `job_db`. Use `--database-root DIR` when
they are elsewhere.

## Run

Run every requested group, including all 113 JOB round-3 rewrite groups:

```bash
./run_required_retests.sh --profile all
```

Smaller profiles are available:

```bash
# Graph Q1/Q4/Q7; LSQB Q2/Q5; TPC-H Q7/Q18; all DSB queries; JOB 1a
./run_required_retests.sh --profile fixes

# The exact JOB origin-versus-integrated list from the issue report
./run_required_retests.sh --profile job-integrated

# Every JOB original and every generated Yannakakis round-3 alternative
./run_required_retests.sh --profile job-yannakakis
```

Select one or more query groups while diagnosing a result:

```bash
./run_required_retests.sh --profile fixes --only graph:q4
./run_required_retests.sh --profile fixes --only tpch:q7 --only tpch:q18
```

On a non-Linux development machine, disable `taskset` with `--cpu-list none`.
Useful controls include `--threads`, `--repetitions`, `--warmups`, `--timeout`,
`--seed`, and `--output-dir`. The default is three timing repetitions and the
default per-process
timeout is 7200 seconds. A timeout or SQL error is written explicitly; it can no
longer appear as a silently missing timing.

## Outputs

Each run creates a timestamped directory under `required_retest_results/`:

- `raw_results.csv`: every measured sample, status, wall time, and execution order.
- `summary.csv`: median/minimum/maximum by physical plan.
- `Origin.csv`, `Yan.csv`, `YanPlus_rewrite.csv`, and `YanPlus.csv`: the same raw
  measurements split into one file per testing setting.
- `Origin_summary.csv`, `Yan_summary.csv`, `YanPlus_rewrite_summary.csv`, and
  `YanPlus_summary.csv`: median/minimum/maximum results split by setting.
- `integrated_comparison.csv`: paired origin and Yan+ medians, speedup, and win count.
- `metadata.json`: binaries, settings, databases, affinity, seed, and experiment design.
- `logs/`: stdout/stderr for every timing process.

The `setting` column uses exactly these names:

- `Origin`: original DuckDB plan.
- `Yan`: Yannakakis SQL rewrite.
- `YanPlus_rewrite`: Yannakakis+ SQL rewrite.
- `YanPlus`: integrated Yannakakis+ optimizer.

## Query-name clarification

The DSB SPJ workload has `query099.sql`, not `query101.sql`. The reported
"DSB SPJ Q101" gap is therefore covered as SPJ Q99. DSB aggregate Q100/Q101
remain Q100/Q101 and are included separately.
