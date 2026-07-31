#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
AUTO_RUN="${SCRIPT_PATH}/auto_run.sh"

# echo "Starting graph rewrite"
# "${AUTO_RUN}" graph graph_rewrite rewriter

FAILED_REWRITE_RUNS=()
FAILED_REWRITE_STATUSES=()

run_rewrite_suite() {
    local label=$1
    local query_directory=$2
    local run_status

    echo "Starting ${label} rewrite"
    if "${AUTO_RUN}" dsb "${query_directory}" rewriter; then
        return
    else
        run_status=$?
    fi
    if [[ "${run_status}" == 130 || "${run_status}" == 143 ]]; then
        exit "${run_status}"
    fi
    FAILED_REWRITE_RUNS+=("${label}")
    FAILED_REWRITE_STATUSES+=("${run_status}")
    echo "Warning: ${label} rewrite completed with query failures (exit ${run_status}); continuing." >&2
}

run_rewrite_suite dsb-agg dsb_agg_rewrite

run_rewrite_suite dsb-spj dsb_spj_rewrite

# echo "Starting tpch rewrite"
# "${AUTO_RUN}" tpch tpch_rewrite rewriter

# echo "Starting lsqb rewrite"
# "${AUTO_RUN}" lsqb lsqb_rewrite rewriter

if ((${#FAILED_REWRITE_RUNS[@]} > 0)); then
    echo "Failed rewrite suites: ${#FAILED_REWRITE_RUNS[@]}" >&2
    for ((failure_idx = 0; failure_idx < ${#FAILED_REWRITE_RUNS[@]}; failure_idx++)); do
        echo "  ${FAILED_REWRITE_RUNS[failure_idx]}: exit=${FAILED_REWRITE_STATUSES[failure_idx]}" >&2
    done
    exit 1
fi

echo "All rewrite suites completed successfully."
