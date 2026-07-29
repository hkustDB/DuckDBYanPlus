#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

usage() {
    cat >&2 <<EOF
Usage: $0 <database> <query_dir> <origin|yanplus> [threads] [cpu_list] [repetitions]

Examples:
  $0 lsqb lsqb origin
  $0 lsqb lsqb yanplus 64 0-15,24-71 5

A bare database name such as "lsqb" resolves to <repository>/lsqb_db.
The two default executables are produced by ./build_duckdb_variants.sh.
EOF
}

if [[ $# -lt 3 || $# -gt 6 ]]; then
    usage
    exit 1
fi

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DATABASE_ARGUMENT=$1
INPUT_DIR=$2
VARIANT_ARGUMENT=$3
NUM_THREADS=${4:-64}
CPU_LIST=${5:-${YANPLUS_CPU_LIST:-0-15,24-71}}
REPETITIONS=${6:-${YANPLUS_REPETITIONS:-5}}

case "${VARIANT_ARGUMENT}" in
origin | duckdb_origin)
    VARIANT=origin
    DUCKDB_BIN=${DUCKDB_ORIGIN_BIN:-"${SCRIPT_PATH}/build/duckdb_origin/duckdb"}
    EXPECTED_YANPLUS_SETTING_COUNT=0
    ;;
yanplus | duckdb_YanPlus)
    VARIANT=yanplus
    DUCKDB_BIN=${DUCKDB_YANPLUS_BIN:-"${SCRIPT_PATH}/build/duckdb_YanPlus/duckdb"}
    EXPECTED_YANPLUS_SETTING_COUNT=1
    ;;
*)
    echo "Error: variant must be 'origin' or 'yanplus', got '${VARIANT_ARGUMENT}'." >&2
    usage
    exit 1
    ;;
esac

if [[ "${DUCKDB_BIN}" != /* ]]; then
    DUCKDB_BIN="${SCRIPT_PATH}/${DUCKDB_BIN}"
fi
if [[ "${INPUT_DIR}" = /* ]]; then
    INPUT_DIR_PATH=${INPUT_DIR}
else
    INPUT_DIR_PATH="${SCRIPT_PATH}/${INPUT_DIR}"
fi
if [[ "${DATABASE_ARGUMENT}" = /* ]]; then
    DATABASE_PATH=${DATABASE_ARGUMENT}
elif [[ "${DATABASE_ARGUMENT}" == */* || "${DATABASE_ARGUMENT}" == *_db ||
        "${DATABASE_ARGUMENT}" == *.duckdb || "${DATABASE_ARGUMENT}" == *.db ]]; then
    DATABASE_PATH="${SCRIPT_PATH}/${DATABASE_ARGUMENT}"
else
    DATABASE_PATH="${SCRIPT_PATH}/${DATABASE_ARGUMENT}_db"
fi

if [[ $(uname -s) != Linux ]]; then
    echo "Error: reproducible CPU affinity requires Linux taskset." >&2
    exit 1
fi
for required_command in taskset timeout awk grep; do
    if ! command -v "${required_command}" >/dev/null 2>&1; then
        echo "Error: required command '${required_command}' is not installed." >&2
        exit 1
    fi
done
if ! [[ "${NUM_THREADS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: threads must be a positive integer, got '${NUM_THREADS}'." >&2
    exit 1
fi
if ! [[ "${REPETITIONS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: repetitions must be a positive integer, got '${REPETITIONS}'." >&2
    exit 1
fi
if [[ ! -x "${DUCKDB_BIN}" ]]; then
    echo "Error: ${VARIANT} executable not found or not executable: ${DUCKDB_BIN}" >&2
    echo "Run ./build_duckdb_variants.sh first, or set the matching DUCKDB_*_BIN variable." >&2
    exit 1
fi
if [[ ! -f "${DATABASE_PATH}" ]]; then
    echo "Error: database file does not exist: ${DATABASE_PATH}" >&2
    exit 1
fi
if [[ ! -d "${INPUT_DIR_PATH}" ]]; then
    echo "Error: query directory does not exist: ${INPUT_DIR_PATH}" >&2
    exit 1
fi
if ! taskset --cpu-list "${CPU_LIST}" true >/dev/null 2>&1; then
    echo "Error: CPU list '${CPU_LIST}' is invalid or outside this process's allowed CPU set." >&2
    exit 1
fi

AVAILABLE_CPU_COUNT=$(taskset --cpu-list "${CPU_LIST}" nproc 2>/dev/null)
if ! [[ "${AVAILABLE_CPU_COUNT}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: could not determine the CPU count for '${CPU_LIST}'." >&2
    exit 1
fi
if ((AVAILABLE_CPU_COUNT < NUM_THREADS)); then
    echo "Error: ${NUM_THREADS} DuckDB threads exceed the ${AVAILABLE_CPU_COUNT} CPUs in '${CPU_LIST}'." >&2
    exit 1
fi

# Verify that a stale or incorrectly compiled executable cannot silently enter
# the comparison under the wrong label.
YANPLUS_SETTING_COUNT=$(taskset --cpu-list "${CPU_LIST}" "${DUCKDB_BIN}" -csv -noheader \
    -c "SELECT count(*) FROM duckdb_settings() WHERE name = 'yanplus_enable';" 2>/dev/null | tr -d '\r')
if [[ "${YANPLUS_SETTING_COUNT}" != "${EXPECTED_YANPLUS_SETTING_COUNT}" ]]; then
    echo "Error: ${DUCKDB_BIN} is not a '${VARIANT}' build." >&2
    echo "Expected yanplus_enable setting count ${EXPECTED_YANPLUS_SETTING_COUNT}, got ${YANPLUS_SETTING_COUNT}." >&2
    exit 1
fi
if [[ "${VARIANT}" == yanplus ]]; then
    YANPLUS_DEFAULTS=$(taskset --cpu-list "${CPU_LIST}" "${DUCKDB_BIN}" -csv -noheader \
        -c "SELECT current_setting('yanplus_enable')::VARCHAR || '|' || current_setting('yanplus_semijoin_filter')::VARCHAR;" \
        2>/dev/null | tr -d '\r')
    if [[ "${YANPLUS_DEFAULTS}" != "true|BLOOM" ]]; then
        echo "Error: Yan+ must default to enabled with the BLOOM filter; got '${YANPLUS_DEFAULTS}'." >&2
        exit 1
    fi
fi

# DuckDB v1.5 can automatically pin workers on machines with more than 64
# logical CPUs. Rebuild its worker pool with internal pinning disabled so that
# taskset remains the only affinity policy. Older v1.5 baselines without the
# setting retain the normal SET threads behavior.
THREAD_SETUP_SQL="SET threads = ${NUM_THREADS};"
PIN_THREADS_COUNT=$(taskset --cpu-list "${CPU_LIST}" "${DUCKDB_BIN}" -csv -noheader \
    -c "SELECT count(*) FROM duckdb_settings() WHERE name = 'pin_threads';" 2>/dev/null | tr -d '\r' || true)
if [[ "${PIN_THREADS_COUNT}" == 1 ]]; then
    THREAD_SETUP_SQL="SET pin_threads = 'off'; SET threads = 1; SET threads = ${NUM_THREADS};"
fi

DUCKDB_VERSION=$(taskset --cpu-list "${CPU_LIST}" "${DUCKDB_BIN}" -csv -noheader \
    -c "SELECT version();" 2>/dev/null | tr -d '\r')

shopt -s nullglob
QUERY_FILES=("${INPUT_DIR_PATH}"/*.sql)
if ((${#QUERY_FILES[@]} == 0)); then
    echo "Error: no .sql queries found in ${INPUT_DIR_PATH}." >&2
    exit 1
fi

# The committed LSQB BI templates contain named placeholders. These defaults
# are valid LSQB parameter values and can be overridden for a particular scale
# factor without changing the query files.
LSQB_COUNTRY=${LSQB_COUNTRY:-China}
LSQB_TAG_CLASS=${LSQB_TAG_CLASS:-Song}
LSQB_START_DATE=${LSQB_START_DATE:-2012-08-29}
LSQB_END_DATE=${LSQB_END_DATE:-2012-11-24}
export LSQB_COUNTRY LSQB_TAG_CLASS LSQB_START_DATE LSQB_END_DATE

CURRENT_TEMP=
cleanup() {
    if [[ -n "${CURRENT_TEMP}" && -f "${CURRENT_TEMP}" ]]; then
        rm -f -- "${CURRENT_TEMP}"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Variant: ${VARIANT}"
echo "DuckDB: ${DUCKDB_BIN} (${DUCKDB_VERSION})"
echo "Database: ${DATABASE_PATH}"
echo "Queries: ${INPUT_DIR_PATH} (${#QUERY_FILES[@]} files)"
echo "Experiment threads: ${NUM_THREADS}"
echo "Experiment CPU list: ${CPU_LIST} (${AVAILABLE_CPU_COUNT} available CPUs)"
echo "Measured repetitions: ${REPETITIONS} (one untimed warm-up per repetition)"

for QUERY in "${QUERY_FILES[@]}"; do
    filename=$(basename -- "${QUERY}" .sql)
    LOG_FILE="${INPUT_DIR_PATH}/log_${filename}_${VARIANT}.txt"
    TIME_FILE="${INPUT_DIR_PATH}/time_${filename}_${VARIANT}.txt"
    CURRENT_TEMP=$(mktemp "/tmp/duckdb-${VARIANT}.XXXXXX.sql")

    # All default benchmark suites contain one read-only query per file. Render
    # LSQB placeholders, then remove only the final statement terminator before
    # placing that query inside COPY (...).
    {
        printf 'COPY (\n'
        awk '
            function replace_literal(text, needle, replacement, position, result) {
                result = ""
                while ((position = index(text, needle)) != 0) {
                    result = result substr(text, 1, position - 1) replacement
                    text = substr(text, position + length(needle))
                }
                return result text
            }
            function sql_string(value) {
                return apostrophe replace_literal(value, apostrophe, apostrophe apostrophe) apostrophe
            }
            BEGIN {
                apostrophe = sprintf("%c", 39)
                country = sql_string(ENVIRON["LSQB_COUNTRY"])
                tag_class = sql_string(ENVIRON["LSQB_TAG_CLASS"])
                start_date = sql_string(ENVIRON["LSQB_START_DATE"])
                end_date = sql_string(ENVIRON["LSQB_END_DATE"])
            }
            {
                rendered = replace_literal($0, ":country", country)
                rendered = replace_literal(rendered, ":tagClass", tag_class)
                rendered = replace_literal(rendered, ":startDate", start_date)
                rendered = replace_literal(rendered, ":endDate", end_date)
                line[NR] = rendered
            }
            END {
                last = NR
                while (last > 0 && line[last] ~ /^[[:space:]]*$/) {
                    last--
                }
                if (last == 0) {
                    exit 1
                }
                sub(/[[:space:]]*;[[:space:]]*$/, "", line[last])
                for (i = 1; i <= NR; i++) {
                    print line[i]
                }
            }
        ' "${QUERY}"
        printf ") TO '/dev/null' (FORMAT CSV);\n"
    } >"${CURRENT_TEMP}"

    if grep -Eq ':(country|tagClass|startDate|endDate)([^[:alnum:]_]|$)' "${CURRENT_TEMP}"; then
        echo "Error: unresolved LSQB parameter in ${QUERY}." >&2
        exit 1
    fi

    {
        echo "# variant=${VARIANT}"
        echo "# binary=${DUCKDB_BIN}"
        echo "# version=${DUCKDB_VERSION}"
        echo "# database=${DATABASE_PATH}"
        echo "# query=${QUERY}"
        echo "# threads=${NUM_THREADS}"
        echo "# cpu_list=${CPU_LIST}"
        echo "# repetitions=${REPETITIONS}"
        if [[ "${QUERY}" == "${SCRIPT_PATH}/lsqb/"* ]]; then
            echo "# lsqb_parameters=country:${LSQB_COUNTRY},tagClass:${LSQB_TAG_CLASS},startDate:${LSQB_START_DATE},endDate:${LSQB_END_DATE}"
        fi
    } >"${LOG_FILE}"
    : >"${TIME_FILE}"

    echo "Start ${VARIANT}: ${QUERY}"
    for ((current_task = 1; current_task <= REPETITIONS; current_task++)); do
        echo "  repetition ${current_task}/${REPETITIONS}"
        RUN_OUTPUT=
        if RUN_OUTPUT=$(timeout --signal=KILL 2h taskset --cpu-list "${CPU_LIST}" \
            "${DUCKDB_BIN}" -bail -readonly "${DATABASE_PATH}" \
            -c "${THREAD_SETUP_SQL}" \
            -c ".timer off" \
            -c ".read ${CURRENT_TEMP}" \
            -c ".timer on" \
            -c ".read ${CURRENT_TEMP}" 2>&1); then
            :
        else
            status=$?
            printf '%s\n' "${RUN_OUTPUT}" | tee -a "${LOG_FILE}" >&2
            echo "Error: DuckDB experiment failed for ${QUERY} (exit ${status})." >&2
            exit "${status}"
        fi
        printf '%s\n' "${RUN_OUTPUT}" | tee -a "${LOG_FILE}"
        ELAPSED=$(printf '%s\n' "${RUN_OUTPUT}" |
            awk '/^Run Time \(s\): real / { value = $5 } END { print value }')
        if ! [[ "${ELAPSED}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            echo "Error: could not parse a numeric DuckDB timer value for ${QUERY}." >&2
            exit 1
        fi
        printf '%s\n' "${ELAPSED}" >>"${TIME_FILE}"
    done

    awk '{ sum += $1 } END { if (NR) print "AVG", sum / NR }' "${TIME_FILE}" >>"${TIME_FILE}"
    rm -f -- "${CURRENT_TEMP}"
    CURRENT_TEMP=
    echo "End ${VARIANT}: ${QUERY}"
done
