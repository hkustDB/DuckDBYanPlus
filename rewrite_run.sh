#!/bin/bash

trap 'echo "Interrupted"; kill 0; exit 130' INT

# Graph test
# echo "Starting Graph original"
# ./auto_run.sh graph graph_test 1
# echo "Starting Graph RPT"
# ./auto_run.sh graph graph_test 2
# echo "Starting Graph Yan+"
# ./auto_run.sh graph graph_test 3

# echo "Starting graph rewrite"
# ./auto_run.sh graph graph_rewrite_test 6

echo "Starting dsb-agg rewrite"
./auto_run.sh dsb dsb_agg_rewrite 6

echo "Starting dsb-spj rewrite"
./auto_run.sh dsb dsb_spj_rewrite 6

# echo "Starting tpch rewrite"
# ./auto_run.sh tpch tpch_rewrite_test 6

# echo "Starting job rewrite"
# ./auto_run.sh job job_agg_rewrite_test 6

# echo "Starting LSQB original"
# ./auto_run.sh lsqb lsqb_test 1
# echo "Starting LSQB RPT"
# ./auto_run.sh lsqb lsqb_test 2
# echo "Starting LSQB Yan+"
# ./auto_run.sh lsqb lsqb_test 3

# echo "Starting lsqb rewrite"
# ./auto_run.sh lsqb lsqb_rewrite_test 6