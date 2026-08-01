#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
AUTO_RUN="${SCRIPT_PATH}/auto_run.sh"
DATABASE_ROOT=${YANPLUS_DATABASE_ROOT:-"${SCRIPT_PATH}"}
NUM_THREADS=${YANPLUS_THREADS:-64}
CPU_LIST=${YANPLUS_CPU_LIST:-0-31,36-67}
REPETITIONS=${YANPLUS_REPETITIONS:-3}
VARIANT_ORDER=${YANPLUS_VARIANT_ORDER:-"origin yanplus"}
REWRITER_SELECTION=${YANPLUS_REWRITER_SUITES:-dsb}
REWRITER_SKIP_SELECTION=${YANPLUS_REWRITER_SKIP:-}
ORIGIN_SKIP_SELECTION=${YANPLUS_ORIGIN_SKIP:-"graph:q4,q5,q7 lsqb:q8,q9"}
ORIGIN_SKIP_CLI_SET=0

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
ALL_REWRITER_SUITES=(graph lsqb dsb_agg dsb_spj tpch)
REWRITER_SUITES=()
ORIGIN_SKIP_ENTRIES=()

add_rewriter_suite() {
    local candidate=$1
    local existing
    if ((${#REWRITER_SUITES[@]} > 0)); then
        for existing in "${REWRITER_SUITES[@]}"; do
            if [[ "${existing}" == "${candidate}" ]]; then
                return
            fi
        done
    fi
    REWRITER_SUITES+=("${candidate}")
}

remove_rewriter_suite() {
    local candidate=$1
    local existing
    local retained=()
    if ((${#REWRITER_SUITES[@]} > 0)); then
        for existing in "${REWRITER_SUITES[@]}"; do
            if [[ "${existing}" != "${candidate}" ]]; then
                retained+=("${existing}")
            fi
        done
    fi
    if ((${#retained[@]} > 0)); then
        REWRITER_SUITES=("${retained[@]}")
    else
        REWRITER_SUITES=()
    fi
}

expand_rewriter_token() {
    local token=$1
    local mode=$2
    local suite
    case "${token}" in
    all)
        for suite in "${ALL_REWRITER_SUITES[@]}"; do
            if [[ "${mode}" == add ]]; then
                add_rewriter_suite "${suite}"
            else
                remove_rewriter_suite "${suite}"
            fi
        done
        ;;
    dsb)
        if [[ "${mode}" == add ]]; then
            add_rewriter_suite dsb_agg
            add_rewriter_suite dsb_spj
        else
            remove_rewriter_suite dsb_agg
            remove_rewriter_suite dsb_spj
        fi
        ;;
    graph | lsqb | dsb_agg | dsb_spj | tpch)
        if [[ "${mode}" == add ]]; then
            add_rewriter_suite "${token}"
        else
            remove_rewriter_suite "${token}"
        fi
        ;;
    none)
        if [[ "${mode}" == add ]]; then
            REWRITER_SUITES=()
        fi
        ;;
    *)
        echo "Error: unknown rewriter suite '${token}'." >&2
        echo "Use none, all, dsb, graph, lsqb, dsb_agg, dsb_spj, or tpch." >&2
        exit 1
        ;;
    esac
}

configure_rewriter_suites() {
    local token
    local tokens=()

    read -r -a tokens <<<"${REWRITER_SELECTION}"
    if [[ ${#tokens[@]} -eq 0 ]]; then
        tokens=(none)
    fi
    if [[ ${#tokens[@]} -gt 1 ]]; then
        for token in "${tokens[@]}"; do
            if [[ "${token}" == none ]]; then
                echo "Error: YANPLUS_REWRITER_SUITES=none cannot be combined with other suites." >&2
                exit 1
            fi
        done
    fi
    for token in "${tokens[@]}"; do
        expand_rewriter_token "${token}" add
    done

    tokens=()
    read -r -a tokens <<<"${REWRITER_SKIP_SELECTION}"
    if ((${#tokens[@]} > 0)); then
        for token in "${tokens[@]}"; do
            if [[ "${token}" != none ]]; then
                expand_rewriter_token "${token}" remove
            fi
        done
    fi
}

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

add_origin_skip_entry() {
    local candidate=$1
    local existing
    if ((${#ORIGIN_SKIP_ENTRIES[@]} > 0)); then
        for existing in "${ORIGIN_SKIP_ENTRIES[@]}"; do
            if [[ "${existing}" == "${candidate}" ]]; then
                return
            fi
        done
    fi
    ORIGIN_SKIP_ENTRIES+=("${candidate}")
}

configure_origin_skips() {
    local group
    local groups=()
    local suite
    local query_list
    local query_name
    local query_names=()

    ORIGIN_SKIP_SELECTION=${ORIGIN_SKIP_SELECTION//;/ }
    read -r -a groups <<<"${ORIGIN_SKIP_SELECTION}"
    if ((${#groups[@]} == 0)); then
        return
    fi
    if [[ ${#groups[@]} -eq 1 && "${groups[0]}" == none ]]; then
        return
    fi

    for group in "${groups[@]}"; do
        if [[ "${group}" == none ]]; then
            echo "Error: origin skip value 'none' cannot be combined with query groups." >&2
            exit 1
        fi
        if [[ "${group}" != *:* ]]; then
            echo "Error: origin skip group must use suite:query[,query], got '${group}'." >&2
            exit 1
        fi

        suite=${group%%:*}
        query_list=${group#*:}
        if [[ -z "${suite}" || -z "${query_list}" ]]; then
            echo "Error: origin skip group must include both suite and query names: '${group}'." >&2
            exit 1
        fi
        if ! suite_directory "${suite}" >/dev/null; then
            echo "Error: unknown suite in origin skip group: '${suite}'." >&2
            exit 1
        fi

        query_list=${query_list//,/ }
        query_names=()
        read -r -a query_names <<<"${query_list}"
        if ((${#query_names[@]} == 0)); then
            echo "Error: no query names in origin skip group '${group}'." >&2
            exit 1
        fi
        for query_name in "${query_names[@]}"; do
            query_name=${query_name%.sql}
            if ! [[ "${query_name}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
                echo "Error: invalid query basename in origin skip group: '${query_name}'." >&2
                exit 1
            fi
            add_origin_skip_entry "${suite}:${query_name}"
        done
    done
}

origin_skip_queries_for_suite() {
    local candidate_suite=$1
    local entry
    local result=
    if ((${#ORIGIN_SKIP_ENTRIES[@]} > 0)); then
        for entry in "${ORIGIN_SKIP_ENTRIES[@]}"; do
            if [[ "${entry%%:*}" == "${candidate_suite}" ]]; then
                if [[ -n "${result}" ]]; then
                    result="${result} "
                fi
                result="${result}${entry#*:}"
            fi
        done
    fi
    printf '%s\n' "${result}"
}

rewriter_suite_directory() {
    case "$1" in
    graph)
        printf 'graph_rewrite\n'
        ;;
    lsqb)
        printf 'lsqb_rewrite\n'
        ;;
    dsb_agg)
        printf 'dsb_agg_rewrite\n'
        ;;
    dsb_spj)
        printf 'dsb_spj_rewrite\n'
        ;;
    tpch)
        printf 'tpch_rewrite\n'
        ;;
    *)
        return 1
        ;;
    esac
}

rewriter_enabled_for_suite() {
    local candidate=$1
    local enabled_suite
    if ((${#REWRITER_SUITES[@]} > 0)); then
        for enabled_suite in "${REWRITER_SUITES[@]}"; do
            if [[ "${candidate}" == "${enabled_suite}" ]]; then
                return 0
            fi
        done
    fi
    return 1
}

usage() {
    cat >&2 <<EOF
Usage: $0 [--rewriter=SELECTION] [--skip-rewriter=SELECTION]
          [--skip-origin=SUITE:QUERY,...] [--no-origin-skip]
          [graph|lsqb|dsb_agg|dsb_spj|tpch|job ...]

With no arguments, Yan+ runs every committed benchmark query. Origin runs every
query except Graph q4/q5/q7 and LSQB q8/q9. The compiled variants run first
origin and then Yan+. Rewritten SQL runs with the origin binary for DSB only by
default.

Options:
  --rewriter=SELECTION       override the rewriter suite selection
  --skip-rewriter=SELECTION  remove suites from the rewriter selection
  --no-rewriter              disable all rewritten-query runs
  --skip-origin=GROUP        replace defaults with suite:query[,query]; repeatable
  --no-origin-skip           run every selected query with origin

Environment:
  YANPLUS_DATABASE_ROOT   directory containing graph_db, lsqb_db, dsb_db,
                          tpch_db, and job_db (default: repository root)
  YANPLUS_THREADS         DuckDB threads (default: 64)
  YANPLUS_CPU_LIST        taskset CPU list (default: 0-31,36-67)
  YANPLUS_REPETITIONS     measured repetitions per query (default: 3)
  YANPLUS_VARIANT_ORDER   "origin yanplus" or "yanplus origin"
  YANPLUS_REWRITER_SUITES rewriter suites: none, all, dsb, or explicit suite
                          names (default: dsb)
  YANPLUS_REWRITER_SKIP   rewriter suites to remove from that selection
  YANPLUS_ORIGIN_SKIP     origin-only suite:query[,query] groups (default:
                          graph:q4,q5,q7 lsqb:q8,q9)
  DUCKDB_REWRITER_BIN     optional origin-compatible binary for rewritten SQL
EOF
}

SELECTED_SUITES=()
for argument in "$@"; do
    case "${argument}" in
    -h | --help)
        usage
        exit 0
        ;;
    --rewriter=*)
        REWRITER_SELECTION=${argument#*=}
        REWRITER_SELECTION=${REWRITER_SELECTION//,/ }
        ;;
    --skip-rewriter=*)
        REWRITER_SKIP_SELECTION=${argument#*=}
        REWRITER_SKIP_SELECTION=${REWRITER_SKIP_SELECTION//,/ }
        ;;
    --no-rewriter)
        REWRITER_SELECTION=none
        ;;
    --skip-origin=*)
        origin_skip_value=${argument#*=}
        if [[ -z "${origin_skip_value}" ]]; then
            echo "Error: --skip-origin requires suite:query[,query]." >&2
            exit 1
        fi
        if ((ORIGIN_SKIP_CLI_SET == 0)) || [[ "${ORIGIN_SKIP_SELECTION}" == none ]]; then
            ORIGIN_SKIP_SELECTION=${origin_skip_value}
        else
            ORIGIN_SKIP_SELECTION="${ORIGIN_SKIP_SELECTION} ${origin_skip_value}"
        fi
        ORIGIN_SKIP_CLI_SET=1
        ;;
    --no-origin-skip)
        ORIGIN_SKIP_SELECTION=none
        ORIGIN_SKIP_CLI_SET=1
        ;;
    -*)
        echo "Error: unknown option '${argument}'." >&2
        usage
        exit 1
        ;;
    *)
        SELECTED_SUITES+=("${argument}")
        ;;
    esac
done

if ((${#SELECTED_SUITES[@]} == 0)); then
    SELECTED_SUITES=("${ALL_SUITES[@]}")
fi
configure_rewriter_suites
configure_origin_skips

if [[ ! -x "${AUTO_RUN}" ]]; then
    echo "Error: auto runner is not executable: ${AUTO_RUN}" >&2
    exit 1
fi

PREFLIGHT_FAILED=0
TOTAL_ORIGIN_QUERIES=0
TOTAL_YANPLUS_QUERIES=0
TOTAL_ORIGIN_SKIPPED=0
TOTAL_REWRITER_QUERIES=0
ACTIVE_REWRITER_SUITES=()
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
            origin_skip_queries=$(origin_skip_queries_for_suite "${suite}")
            origin_skip_query_names=()
            read -r -a origin_skip_query_names <<<"${origin_skip_queries}"
            suite_origin_skip_count=0
            if ((${#origin_skip_query_names[@]} > 0)); then
                for skip_query_name in "${origin_skip_query_names[@]}"; do
                    if [[ ! -f "${query_dir}/${skip_query_name}.sql" ]]; then
                        echo "Error: origin skip query does not exist for ${suite}: ${query_dir}/${skip_query_name}.sql" >&2
                        PREFLIGHT_FAILED=1
                    else
                        suite_origin_skip_count=$((suite_origin_skip_count + 1))
                    fi
                done
            fi
            TOTAL_YANPLUS_QUERIES=$((TOTAL_YANPLUS_QUERIES + query_count))
            TOTAL_ORIGIN_QUERIES=$((TOTAL_ORIGIN_QUERIES + query_count - suite_origin_skip_count))
            TOTAL_ORIGIN_SKIPPED=$((TOTAL_ORIGIN_SKIPPED + suite_origin_skip_count))
        fi
    fi
    if [[ ! -f "${database_path}" ]]; then
        echo "Error: missing database for ${suite}: ${database_path}" >&2
        PREFLIGHT_FAILED=1
    fi

    if rewriter_enabled_for_suite "${suite}"; then
        rewrite_directory=$(rewriter_suite_directory "${suite}")
        rewrite_dir="${SCRIPT_PATH}/${rewrite_directory}"
        if [[ ! -d "${rewrite_dir}" ]]; then
            echo "Error: missing rewriter query directory for ${suite}: ${rewrite_dir}" >&2
            PREFLIGHT_FAILED=1
        else
            rewrite_count=$(find "${rewrite_dir}" -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d '[:space:]')
            if [[ "${rewrite_count}" == 0 ]]; then
                echo "Error: no rewritten SQL files found for ${suite}: ${rewrite_dir}" >&2
                PREFLIGHT_FAILED=1
            else
                TOTAL_REWRITER_QUERIES=$((TOTAL_REWRITER_QUERIES + rewrite_count))
                ACTIVE_REWRITER_SUITES+=("${suite}")
            fi
        fi
    fi
done

if ((TOTAL_REWRITER_QUERIES > 0)); then
    rewriter_binary=${DUCKDB_REWRITER_BIN:-${DUCKDB_ORIGIN_BIN:-"${SCRIPT_PATH}/build/duckdb_origin/duckdb"}}
    if [[ "${rewriter_binary}" != /* ]]; then
        rewriter_binary="${SCRIPT_PATH}/${rewriter_binary}"
    fi
    if [[ ! -x "${rewriter_binary}" ]]; then
        echo "Error: missing rewriter/origin executable: ${rewriter_binary}" >&2
        PREFLIGHT_FAILED=1
    fi
fi

if ((PREFLIGHT_FAILED != 0)); then
    echo "Preflight failed. Build both variants and place the database files before running the batch." >&2
    exit 1
fi

echo "Suites: ${SELECTED_SUITES[*]}"
echo "Origin queries: ${TOTAL_ORIGIN_QUERIES} (${TOTAL_ORIGIN_SKIPPED} skipped)"
echo "Yan+ queries: ${TOTAL_YANPLUS_QUERIES}"
echo "Compiled binary/query pairs: $((TOTAL_ORIGIN_QUERIES + TOTAL_YANPLUS_QUERIES))"
if ((TOTAL_REWRITER_QUERIES > 0)); then
    echo "Rewriter suites: ${ACTIVE_REWRITER_SUITES[*]}"
    echo "Rewriter queries: ${TOTAL_REWRITER_QUERIES}"
else
    echo "Rewriter suites: none"
fi
echo "Total query configurations: $((TOTAL_ORIGIN_QUERIES + TOTAL_YANPLUS_QUERIES + TOTAL_REWRITER_QUERIES))"
echo "Threads: ${NUM_THREADS}"
echo "CPU list: ${CPU_LIST}"
echo "Repetitions: ${REPETITIONS}"
echo "Variant order: ${VARIANTS[*]}"

FAILED_RUN_LABELS=()
FAILED_RUN_STATUSES=()

record_failed_run() {
    local run_label=$1
    local run_status=$2
    if [[ "${run_status}" == 130 || "${run_status}" == 143 ]]; then
        exit "${run_status}"
    fi
    FAILED_RUN_LABELS+=("${run_label}")
    FAILED_RUN_STATUSES+=("${run_status}")
    echo "Warning: ${run_label} completed with query failures (exit ${run_status}); continuing." >&2
}

for suite in "${SELECTED_SUITES[@]}"; do
    database_name=$(suite_database "${suite}")
    query_directory=$(suite_directory "${suite}")
    database_path="${DATABASE_ROOT}/${database_name}_db"
    query_dir="${SCRIPT_PATH}/${query_directory}"
    for variant in "${VARIANTS[@]}"; do
        echo
        echo "Starting ${suite} with ${variant}"
        if [[ "${variant}" == origin ]]; then
            origin_skip_queries=$(origin_skip_queries_for_suite "${suite}")
            if YANPLUS_ORIGIN_SKIP_QUERIES="${origin_skip_queries}" \
                "${AUTO_RUN}" "${database_path}" "${query_dir}" "${variant}" \
                "${NUM_THREADS}" "${CPU_LIST}" "${REPETITIONS}"; then
                :
            else
                run_status=$?
                record_failed_run "${suite}:${variant}" "${run_status}"
            fi
        else
            if YANPLUS_ORIGIN_SKIP_QUERIES= \
                "${AUTO_RUN}" "${database_path}" "${query_dir}" "${variant}" \
                "${NUM_THREADS}" "${CPU_LIST}" "${REPETITIONS}"; then
                :
            else
                run_status=$?
                record_failed_run "${suite}:${variant}" "${run_status}"
            fi
        fi
    done
    if rewriter_enabled_for_suite "${suite}"; then
        rewrite_directory=$(rewriter_suite_directory "${suite}")
        rewrite_dir="${SCRIPT_PATH}/${rewrite_directory}"
        echo
        echo "Starting ${suite} with rewriter"
        if YANPLUS_ORIGIN_SKIP_QUERIES= \
            "${AUTO_RUN}" "${database_path}" "${rewrite_dir}" rewriter \
            "${NUM_THREADS}" "${CPU_LIST}" "${REPETITIONS}"; then
            :
        else
            run_status=$?
            record_failed_run "${suite}:rewriter" "${run_status}"
        fi
    fi
done

echo
echo "Attempted $((TOTAL_ORIGIN_QUERIES + TOTAL_YANPLUS_QUERIES + TOTAL_REWRITER_QUERIES)) query configurations."
if ((${#FAILED_RUN_LABELS[@]} > 0)); then
    echo "Failed run groups: ${#FAILED_RUN_LABELS[@]}" >&2
    for ((failure_idx = 0; failure_idx < ${#FAILED_RUN_LABELS[@]}; failure_idx++)); do
        echo "  ${FAILED_RUN_LABELS[failure_idx]}: exit=${FAILED_RUN_STATUSES[failure_idx]}" >&2
    done
    exit 1
fi
echo "All query configurations completed successfully."
