## Yannakakis<sup>+</sup>

This repository contains the implementation of **Yannakakis<sup>+</sup>**, built on
top of [DuckDB v1.5.0](https://github.com/duckdb/duckdb/tree/v1.5.0). Its main features are:

- **Bloom filters** for semi-join reduction, with an optional exact hash-filter backend.
- **Aggregation push-down** for supported queries.
- **GYO** planning for acyclic queries, with experimental bag-based processing
  for supported cyclic queries.

## Build

Build this repository in the same way as the original DuckDB. See the
[DuckDB Build Configuration Guide](https://duckdb.org/docs/stable/dev/building/build_configuration.html)
for additional targets and flags.

```bash
make                  # Build optimized release version
make release          # Same as 'make'
make debug            # Build with debug symbols
GEN=ninja make        # Use Ninja as backend
BUILD_BENCHMARK=1 make # Build with benchmark support
```

## Baselines

For comparison, we use the following baselines:

- **DuckDB1.5**: [DuckDB v1.5.0](https://github.com/duckdb/duckdb/tree/v1.5.0)
- **DuckDB1.5-Yan (rewrite)**: a rewrite-based implementation of the Yannakakis algorithm. [Paper](https://dl.acm.org/doi/10.5555/1286831.1286840) · [Repo](https://github.com/hkustDB/Quorion)
- **DuckDB1.5-Yan<sup>+</sup> (rewrite)**: a rewrite-based implementation of the Yannakakis<sup>+</sup> algorithm. [Paper](https://doi.org/10.1145/3725423) · [Repo](https://github.com/hkustDB/Quorion)

## Benchmark

- Sub-Graph Pattern Benchmark (SGPB)
- LSQB
- TPC-H & Decision Support Benchmark (DSB)
- Join Order Benchmark (JOB)

See [the experiment guide](auto_test/README.md) for configuration, experiment
builds, benchmark commands, rewrite baselines, robustness tests, and plotting.

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
