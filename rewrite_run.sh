#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
AUTO_RUN="${SCRIPT_PATH}/auto_run.sh"

# echo "Starting graph rewrite"
# "${AUTO_RUN}" graph graph_rewrite rewriter

echo "Starting dsb-agg rewrite"
"${AUTO_RUN}" dsb dsb_agg_rewrite rewriter

echo "Starting dsb-spj rewrite"
"${AUTO_RUN}" dsb dsb_spj_rewrite rewriter

# echo "Starting tpch rewrite"
# "${AUTO_RUN}" tpch tpch_rewrite rewriter

# echo "Starting lsqb rewrite"
# "${AUTO_RUN}" lsqb lsqb_rewrite rewriter
