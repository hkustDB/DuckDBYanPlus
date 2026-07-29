#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
AUTO_RUN="${SCRIPT_PATH}/auto_run.sh"
DATABASE_ROOT=${YANPLUS_DATABASE_ROOT:-"${SCRIPT_PATH}"}
NUM_THREADS=${YANPLUS_THREADS:-64}
CPU_LIST=${YANPLUS_CPU_LIST:-0-15,24-71}
REPETITIONS=${YANPLUS_REPETITIONS:-5}
VARIANT_ORDER=${YANPLUS_VARIANT_ORDER:-"origin yanplus"}

if [[ ! -d "${DATABASE_ROOT}" ]]; then
    echo "Error: database root does not exist: ${DATABASE_ROOT}" >&2
    exit 1
fi
DATABASE_ROOT=$(cd -- "${DATABASE_ROOT}" && pwd)
read -r -a VARIANTS <<<"${VARIANT_ORDER}"
if [[ ${#VARIANTS[@]} -ne 2 ]]; then
    echo "Error: YANPLUS_VARIANT_ORDER must contain 'origin yanplus' in either order." >&2
    exit 1
fi
case "${VARIANTS[0]}:${VARIANTS[1]}" in
origin:yanplus | yanplus:origin)
    ;;
*)
    echo "Error: YANPLUS_VARIANT_ORDER must contain 'origin yanplus' in either order." >&2
    exit 1
    ;;
esac

ALL_SUITES=(graph lsqb dsb_agg dsb_spj tpch job)

suite_database() {
    case "$1" in
    graph | lsqb | tpch | job)
        printf '%s\n' "$1"
        ;;
    dsb_agg | dsb_spj)
        printf 'dsb\n'
        ;;
    *)
        return 1
        ;;
    esac
}

suite_directory() {
    case "$1" in
    graph | lsqb | dsb_agg | dsb_spj | tpch)
        printf '%s\n' "$1"
        ;;
    job)
        printf 'job_agg\n'
        ;;
    *)
        return 1
        ;;
    esac
}

usage() {
    cat >&2 <<EOF
Usage: $0 [graph|lsqb|dsb_agg|dsb_spj|tpch|job ...]

With no arguments, every committed benchmark query is run with both compiled
variants, first origin and then Yan+.

Environment:
  YANPLUS_DATABASE_ROOT   directory containing graph_db, lsqb_db, dsb_db,
                          tpch_db, and job_db (default: repository root)
  YANPLUS_THREADS         DuckDB threads (default: 64)
  YANPLUS_CPU_LIST        taskset CPU list (default: 0-15,24-71)
  YANPLUS_REPETITIONS     measured repetitions per query (default: 5)
  YANPLUS_VARIANT_ORDER   "origin yanplus" or "yanplus origin"
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    usage
    exit 0
fi

if (($# == 0)); then
    SELECTED_SUITES=("${ALL_SUITES[@]}")
else
    SELECTED_SUITES=("$@")
fi

if [[ ! -x "${AUTO_RUN}" ]]; then
    echo "Error: auto runner is not executable: ${AUTO_RUN}" >&2
    exit 1
fi

PREFLIGHT_FAILED=0
TOTAL_QUERIES=0
for variant in "${VARIANTS[@]}"; do
    if [[ "${variant}" == origin ]]; then
        binary=${DUCKDB_ORIGIN_BIN:-"${SCRIPT_PATH}/build/duckdb_origin/duckdb"}
    else
        binary=${DUCKDB_YANPLUS_BIN:-"${SCRIPT_PATH}/build/duckdb_YanPlus/duckdb"}
    fi
    if [[ "${binary}" != /* ]]; then
        binary="${SCRIPT_PATH}/${binary}"
    fi
    if [[ ! -x "${binary}" ]]; then
        echo "Error: missing ${variant} executable: ${binary}" >&2
        PREFLIGHT_FAILED=1
    fi
done

for suite in "${SELECTED_SUITES[@]}"; do
    if ! database_name=$(suite_database "${suite}"); then
        echo "Error: unknown suite '${suite}'." >&2
        usage
        exit 1
    fi
    query_directory=$(suite_directory "${suite}")
    query_dir="${SCRIPT_PATH}/${query_directory}"
    database_path="${DATABASE_ROOT}/${database_name}_db"
    if [[ ! -d "${query_dir}" ]]; then
        echo "Error: missing query directory for ${suite}: ${query_dir}" >&2
        PREFLIGHT_FAILED=1
    else
        query_count=$(find "${query_dir}" -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d '[:space:]')
        if [[ "${query_count}" == 0 ]]; then
            echo "Error: no SQL files found for ${suite}: ${query_dir}" >&2
            PREFLIGHT_FAILED=1
        else
            TOTAL_QUERIES=$((TOTAL_QUERIES + query_count))
        fi
    fi
    if [[ ! -f "${database_path}" ]]; then
        echo "Error: missing database for ${suite}: ${database_path}" >&2
        PREFLIGHT_FAILED=1
    fi
done

if ((PREFLIGHT_FAILED != 0)); then
    echo "Preflight failed. Build both variants and place the database files before running the batch." >&2
    exit 1
fi

echo "Suites: ${SELECTED_SUITES[*]}"
echo "Queries per variant: ${TOTAL_QUERIES}"
echo "Binary/query pairs: $((TOTAL_QUERIES * 2))"
echo "Threads: ${NUM_THREADS}"
echo "CPU list: ${CPU_LIST}"
echo "Repetitions: ${REPETITIONS}"
echo "Variant order: ${VARIANTS[*]}"

for suite in "${SELECTED_SUITES[@]}"; do
    database_name=$(suite_database "${suite}")
    query_directory=$(suite_directory "${suite}")
    database_path="${DATABASE_ROOT}/${database_name}_db"
    query_dir="${SCRIPT_PATH}/${query_directory}"
    for variant in "${VARIANTS[@]}"; do
        echo
        echo "Starting ${suite} with ${variant}"
        "${AUTO_RUN}" "${database_path}" "${query_dir}" "${variant}" \
            "${NUM_THREADS}" "${CPU_LIST}" "${REPETITIONS}"
    done
done

echo
echo "Completed ${TOTAL_QUERIES} queries with both origin and Yan+."
