#!/bin/bash

set -o pipefail

trap 'echo "Interrupted"; kill 0; exit 130' INT

uNames=`uname -s`
osName=${uNames: 0: 4}
if [ "$osName" == "Darw" ] # Darwin
then
    COMMAND="ghead"
elif [ "$osName" == "Linu" ] # Linux
then
    COMMAND="head"
fi

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=$(dirname "${SCRIPT}")

INPUT_DIR=$2
INPUT_DIR_PATH="${SCRIPT_PATH}/${INPUT_DIR}"

# graph, tpch, lsqb
DATABASE=$1

NUM_THREADS=${4:-64}
CPU_LIST=${5:-${YANPLUS_CPU_LIST:-0-15,24-71}}

DUCK_NUM=${3:-1}

declare -A DUCK_MAP=(
  [1]="./duckdb_origin"
  [2]="./duckdb_RPT"
  [3]="./duckdb_YanPlus"
  [4]="./duckdb_YanPlus_GYO"
  [5]="./duckdb_YanPlus_NoGYO"
  [6]="./duckdb_origin"
)

if [[ -z ${DUCK_MAP[$DUCK_NUM]} ]]; then
  echo "Usage: $0 <db> <dir> <duck_num> [threads] [cpu_list]" >&2
  echo "duck_num: 1-5=original logic, 6=multi-statement handling" >&2
  exit 1
fi
DUCKDB_BIN=${DUCK_MAP[$DUCK_NUM]}

if [ "$osName" != "Linu" ]; then
    echo "Error: reproducible CPU affinity requires Linux taskset." >&2
    exit 1
fi
if ! command -v taskset >/dev/null 2>&1; then
    echo "Error: taskset is required (install the util-linux package)." >&2
    exit 1
fi
if ! [[ "${NUM_THREADS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: threads must be a positive integer, got '${NUM_THREADS}'." >&2
    exit 1
fi
if [ ! -x "${DUCKDB_BIN}" ]; then
    echo "Error: DuckDB executable not found or not executable: ${DUCKDB_BIN}" >&2
    exit 1
fi

AVAILABLE_CPU_COUNT=$(taskset --cpu-list "${CPU_LIST}" nproc 2>/dev/null)
if ! [[ "${AVAILABLE_CPU_COUNT}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: invalid or unavailable CPU list '${CPU_LIST}'." >&2
    exit 1
fi
if [ "${AVAILABLE_CPU_COUNT}" -lt "${NUM_THREADS}" ]; then
    echo "Error: ${NUM_THREADS} DuckDB threads exceed the ${AVAILABLE_CPU_COUNT} CPUs in '${CPU_LIST}'." >&2
    exit 1
fi

# DuckDB v1.5 automatically pins workers on machines with more than 64 CPUs.
# Rebuild its worker pool with internal pinning disabled so taskset remains the
# authoritative affinity policy. Older baselines without this setting retain
# their normal SET threads behavior.
THREAD_SETUP_SQL="SET threads TO ${NUM_THREADS};"
PIN_THREADS_COUNT=$(taskset --cpu-list "${CPU_LIST}" "${DUCKDB_BIN}" -csv -noheader \
    -c "SELECT count(*) FROM duckdb_settings() WHERE name = 'pin_threads';" 2>/dev/null || true)
if [ "${PIN_THREADS_COUNT}" = "1" ]; then
    THREAD_SETUP_SQL="SET pin_threads = 'off'; SET threads = 1; SET threads = ${NUM_THREADS};"
fi

echo "Experiment threads: ${NUM_THREADS}"
echo "Experiment CPU list: ${CPU_LIST} (${AVAILABLE_CPU_COUNT} available CPUs)"

# Suffix function
function FileSuffix() {
    local filename="$1"
    if [ -n "$filename" ]; then
        echo "${filename##*.}"
    fi
}

function IsSuffix() {
    local filename="$1"
    if [ "$(FileSuffix ${filename})" = "sql" ]
    then
        return 0
    else 
        return 1
    fi
}

# Function to handle multi-statement SQL files (DUCK_NUM=6)
function ProcessMultiStatementSQL() {
    local query_file="$1"
    local submit_query_1="$2"
    local submit_query_2="$3"
    
    # Check if file contains CREATE statements
    local create_count=$(grep -c "^[[:space:]]*[Cc][Rr][Ee][Aa][Tt][Ee]" "$query_file")
    
    if [[ $create_count -gt 0 ]]; then
        echo "Multi-statement SQL detected: $create_count CREATE statements"
        
        # Split: all but last statement to setup file
        ${COMMAND} -n -1 "$query_file" > "$submit_query_1"
        
        # Wrap final SELECT in COPY statement
        echo "COPY (" > "$submit_query_2"
        tail -n 1 "$query_file" | sed 's/;//g' >> "$submit_query_2"
        echo ") TO '/dev/null' (DELIMITER ',');" >> "$submit_query_2"
        
        return 1  # Multi-statement file
    else
        echo "Single statement SQL detected"
        
        # Wrap entire query in COPY statement
        echo "COPY (" > "$submit_query_1"
        cat "$query_file" | sed 's/;//g' >> "$submit_query_1"
        echo ") TO '/dev/null' (DELIMITER ',');" >> "$submit_query_1"
        
        return 0  # Single statement file
    fi
}

for file in $(ls ${INPUT_DIR_PATH})
do
    IsSuffix ${file}
    ret=$?
    if [ $ret -eq 0 ]
    then
        filename="${file%.*}"
        LOG_FILE="${INPUT_DIR_PATH}/log_${filename}_${DUCK_NUM}.txt"
        TIME_FILE="${INPUT_DIR_PATH}/time_${filename}_${DUCK_NUM}.txt"
        rm -f $LOG_FILE $TIME_FILE
        touch $LOG_FILE $TIME_FILE
        QUERY="${INPUT_DIR_PATH}/${file}"
        RAN=$RANDOM
        
        echo "Start ${DUCKDB_BIN} Task at ${QUERY}"
        
        # Different handling based on DUCK_NUM
        if [[ $DUCK_NUM -eq 6 ]]; then
            # DUCK_NUM=6: Multi-statement handling with file separation
            SUBMIT_QUERY_1="${INPUT_DIR_PATH}/query_${RAN}_setup.sql"
            SUBMIT_QUERY_2="${INPUT_DIR_PATH}/query_${RAN}_exec.sql"
            rm -f "${SUBMIT_QUERY_1}" "${SUBMIT_QUERY_2}"
            touch "${SUBMIT_QUERY_1}" "${SUBMIT_QUERY_2}"
            
            # Process SQL file and determine execution strategy
            ProcessMultiStatementSQL "$QUERY" "$SUBMIT_QUERY_1" "$SUBMIT_QUERY_2"
            is_multi_statement=$?
            
            for ((current_task=1; current_task<=5; current_task++)); 
            do
                echo "Current Task: ${current_task}"
                
                if [[ $is_multi_statement -eq 1 ]]; then
                    # Multi-statement execution: setup + timed execution
                    if ! timeout -s SIGKILL 2h taskset --cpu-list "${CPU_LIST}" "${DUCKDB_BIN}" \
                            -c ".open ${DATABASE}_db" \
                            -c "${THREAD_SETUP_SQL}" \
                            -c ".timer off" \
                            -c ".read ${SUBMIT_QUERY_1}" \
                            -c ".read ${SUBMIT_QUERY_2}" \
                            -c ".timer on" \
                            -c ".read ${SUBMIT_QUERY_2}" \
                            2>&1 | tee -a "${LOG_FILE}" | tail -n 1 | awk '{print $5}' >> "${TIME_FILE}"; then
                        echo "Error: DuckDB experiment failed for ${QUERY}." >&2
                        exit 1
                    fi
                else
                    # Single statement execution
                    if ! timeout -s SIGKILL 2h taskset --cpu-list "${CPU_LIST}" "${DUCKDB_BIN}" \
                            -c ".open ${DATABASE}_db" \
                            -c "${THREAD_SETUP_SQL}" \
                            -c ".timer off" \
                            -c ".read ${SUBMIT_QUERY_1}" \
                            -c ".timer on" \
                            -c ".read ${SUBMIT_QUERY_1}" \
                            2>&1 | tee -a "${LOG_FILE}" | tail -n 1 | awk '{print $5}' >> "${TIME_FILE}"; then
                        echo "Error: DuckDB experiment failed for ${QUERY}." >&2
                        exit 1
                    fi
                fi
            done
            
            # Cleanup separated files
            rm -f "${SUBMIT_QUERY_1}" "${SUBMIT_QUERY_2}"
            
        else
            # DUCK_NUM=1-5: Original logic (wrap entire file in COPY)
            SUBMIT_QUERY="${INPUT_DIR_PATH}/query_${RAN}.sql"
            rm -f "${SUBMIT_QUERY}"
            touch "${SUBMIT_QUERY}"
            echo "COPY (" >> ${SUBMIT_QUERY}
            cat ${QUERY} >> ${SUBMIT_QUERY}
            echo ") TO '/dev/null' (DELIMITER ',');" >> ${SUBMIT_QUERY}
            
            for ((current_task=1; current_task<=5; current_task++)); 
            do
                echo "Current Task: ${current_task}"
                if ! timeout -s SIGKILL 2h taskset --cpu-list "${CPU_LIST}" "${DUCKDB_BIN}" \
                        -c ".open ${DATABASE}_db" \
                        -c "${THREAD_SETUP_SQL}" \
                        -c ".timer off" \
                        -c ".read ${SUBMIT_QUERY}" \
                        -c ".timer on" \
                        -c ".read ${SUBMIT_QUERY}" \
                        2>&1 | tee -a "${LOG_FILE}" | tail -n 1 | awk '{print $5}' >> "${TIME_FILE}"; then
                    echo "Error: DuckDB experiment failed for ${QUERY}." >&2
                    exit 1
                fi
            done
            
            # Cleanup single file
            rm -f "${SUBMIT_QUERY}"
        fi
        
        awk '{s+=$1} END{if(NR) print "AVG", s/NR}' "$TIME_FILE" >> "$TIME_FILE"
        echo "End DuckDB Task..."
    fi
done
