## Yannakakis<sup>+</sup>

This repository contains the implementation of **Yannakakis<sup>+</sup>**, built on top of [DuckDB v1.3.0](https://github.com/duckdb/duckdb/tree/v1.3-ossivalis). It provides a customized version of DuckDB. Compared to the original Yannakakis<sup>+</sup>, this version introduces the following key improvements:

- Replace semi-join in original Yannakakis algorithm with **Bloom Filter**. 
- Apply **aggregation push-down** in the query plan. 
- Use **GYO** algorithm when query is acyclic and fallback to the original DuckDB plan only when the query is cyclic. 

## Build

You can build this repository in the same way as the original DuckDB. A `Makefile` wraps the build process. For available build targets and configuration flags, see the [DuckDB Build Configuration Guide](https://duckdb.org/docs/stable/dev/building/build_configuration.html).

```bash
make                   # Build optimized release version
make release           # Same as 'make'
make debug             # Build with debug symbols
GEN=ninja make         # Use Ninja as backend
BUILD_BENCHMARK=1 make # Build with benchmark support
```

## Baselines

- **DuckDB v1.3.0**: [https://github.com/duckdb/duckdb/tree/v1.3-ossivalis](https://github.com/duckdb/duckdb/tree/v1.3-ossivalis)
- **RPT (Robust Predicate Transfer)**: [[https://github.com/embryo-labs/Robust-Predicate-Transfer](https://github.com/embryo-labs/dynamic-predicate-transfer)]([https://github.com/embryo-labs/Robust-Predicate-Transfer](https://github.com/embryo-labs/dynamic-predicate-transfer))

- **Parachute**: https://github.com/utndatasystems/parachute
- **SYA**: https://github.com/UHasselt-DSI-Data-Systems-Lab/code-reproducability-yannakakis-vldb2025
- **Yannakakis<sup>+</sup> (rewrite)**: https://anonymous.4open.science/r/Yannakakis-Plus-rewrite

## Benchmark

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

DuckDB is a high-performance analytical database system. It is designed to be fast, reliable, portable, and easy to use. DuckDB provides a rich SQL dialect, with support far beyond basic SQL. DuckDB supports arbitrary and nested correlated subqueries, window functions, collations, complex types (arrays, structs, maps), and [several extensions designed to make SQL easier to use](https://duckdb.org/docs/stable/sql/dialect/friendly_sql.html).

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

For development, DuckDB requires [CMake](https://cmake.org), Python3 and a `C++11` compliant compiler. Run `make` in the root directory to compile the sources. For development, use `make debug` to build a non-optimized debug version. You should run `make unit` and `make allunit` to verify that your version works properly after making changes. To test performance, you can run `BUILD_BENCHMARK=1 BUILD_TPCH=1 make` and then perform several standard benchmarks from the root directory by executing `./build/release/benchmark/benchmark_runner`. The details of benchmarks are in our [Benchmark Guide](benchmark/README.md).

Please also refer to our [Build Guide](https://duckdb.org/docs/stable/dev/building/overview) and [Contribution Guide](CONTRIBUTING.md).

## Support

See the [Support Options](https://duckdblabs.com/support/) page.
