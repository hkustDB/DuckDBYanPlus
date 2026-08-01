#!/bin/bash

# Configuration - Define your set of DuckDB paths to test
DUCKDB_PATHS=(
    "./duckdb_origin"
    "./duckdb_RPT"
    "./duckdb_YanPlus"
)

# Fixed experiment policy. Environment variables allow deliberate overrides.
NUM_THREADS=${YANPLUS_THREADS:-64}
CPU_LIST=${YANPLUS_CPU_LIST:-0-31,36-67}

# Configuration - Define query files with their corresponding databases
declare -A QUERY_DATABASE_MAP=(
    ["graph/q1.sql"]="graph_db"
    ["graph/q6.sql"]="graph_db"
    ["lsqb/q1.sql"]="lsqb_db"
    ["lsqb/q6.sql"]="lsqb_db"
    ["dsb_agg/query100.sql"]="dsb_db"
    ["tpch/10.sql"]="tpch_db"
    ["job_agg/3a.sql"]="job_db"
    ["job_agg/22c.sql"]="job_db"
)

# Default database fallback
DEFAULT_DATABASE="graph_db"

# Ensure log directory exists
mkdir -p log

validate_experiment_cpu_policy() {
    if [ "$(uname -s)" != "Linux" ]; then
        echo "Error: reproducible CPU affinity requires Linux taskset." >&2
        return 1
    fi
    if ! command -v taskset >/dev/null 2>&1; then
        echo "Error: taskset is required (install the util-linux package)." >&2
        return 1
    fi
    if ! [[ "${NUM_THREADS}" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: YANPLUS_THREADS must be a positive integer, got '${NUM_THREADS}'." >&2
        return 1
    fi

    local available_cpu_count
    available_cpu_count=$(taskset --cpu-list "${CPU_LIST}" nproc 2>/dev/null)
    if ! [[ "${available_cpu_count}" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: invalid or unavailable CPU list '${CPU_LIST}'." >&2
        return 1
    fi
    if [ "${available_cpu_count}" -lt "${NUM_THREADS}" ]; then
        echo "Error: ${NUM_THREADS} DuckDB threads exceed the ${available_cpu_count} CPUs in '${CPU_LIST}'." >&2
        return 1
    fi
}

thread_setup_sql() {
    local duckdb_path="$1"
    local pin_threads_count
    pin_threads_count=$(taskset --cpu-list "${CPU_LIST}" "${duckdb_path}" -csv -noheader \
        -c "SELECT count(*) FROM duckdb_settings() WHERE name = 'pin_threads';" 2>/dev/null || true)
    if [ "${pin_threads_count}" = "1" ]; then
        echo "SET pin_threads = 'off'; SET threads = 1; SET threads = ${NUM_THREADS};"
    else
        echo "SET threads = ${NUM_THREADS};"
    fi
}

# Function to run memory monitoring for a single DuckDB executable
run_memory_test() {
    local duckdb_path="$1"
    local query_file="$2"
    local database_file="$3"
    
    # Generate log file name with DuckDB executable name - use full query path
    local duckdb_name=$(basename "$duckdb_path")
    local query_path_safe=$(echo "$query_file" | sed 's|/|_|g' | sed 's|\.sql$||')
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="log/memory_${duckdb_name}_${query_path_safe}_${timestamp}.log"
    
    echo "========================================"
    echo "Testing DuckDB: $duckdb_path"
    echo "Query: $query_file"
    echo "Database: $database_file"
    echo "Log file: $log_file"
    echo "========================================"
    
    # Create log file and redirect output
    {
        echo "========================================"
        echo "MEMORY MONITORING LOG"
        echo "========================================"
        echo "DuckDB Path: $duckdb_path"
        echo "Query File: $query_file"
        echo "Database File: $database_file"
        echo "DuckDB Threads: $NUM_THREADS"
        echo "Allowed CPU IDs: $CPU_LIST"
        echo "Start Time: $(date)"
        echo "========================================"
        echo ""
    } > "$log_file"
    
    # Check if DuckDB executable exists and is executable
    if [ ! -x "$duckdb_path" ]; then
        echo "⚠️  SKIP: DuckDB executable not found or not executable: $duckdb_path" | tee -a "$log_file"
        echo ""
        return 1
    fi
    
    # Check if query file exists
    if [ ! -f "$query_file" ]; then
        echo "⚠️  SKIP: Query file not found: $query_file" | tee -a "$log_file"
        echo ""
        return 1
    fi
    
    # Check if database file exists
    if [ ! -f "$database_file" ]; then
        echo "⚠️  SKIP: Database file not found: $database_file" | tee -a "$log_file"
        echo ""
        return 1
    fi
    
    # Start DuckDB query in the background WITHOUT timeout
    echo "Starting DuckDB process..." | tee -a "$log_file"
    local setup_sql
    setup_sql=$(thread_setup_sql "$duckdb_path")
    taskset --cpu-list "$CPU_LIST" "$duckdb_path" \
        -cmd "$setup_sql" "$database_file" < "$query_file" &
    local duckdb_pid=$!
    
    # Initialize variables
    local max_rss=0
    local max_vsz=0
    local max_cpu=0
    local sample_count=0
    local start_time=$(date +%s)
    
    # Create memory CSV file with headers (in log directory)
    local memory_csv="log/memory_${duckdb_name}_${query_path_safe}_${timestamp}_memory.csv"
    echo "Timestamp,Elapsed_Seconds,RSS_KB,VSZ_KB,CPU%,RSS_MB,VSZ_MB" > "$memory_csv"
    
    # Log monitoring start
    echo "DuckDB PID: $duckdb_pid" | tee -a "$log_file"
    echo "Memory monitoring started at: $(date)" | tee -a "$log_file"
    echo "Memory CSV file: $memory_csv" | tee -a "$log_file"
    echo "No timeout - will run until completion" | tee -a "$log_file"
    echo "----------------------------------------" | tee -a "$log_file"
    
    # Monitor while process is running
    echo "Monitoring process PID: $duckdb_pid"
    while kill -0 $duckdb_pid 2>/dev/null; do
        # Get memory stats (RSS and VSZ in KB)
        local stats=$(ps -p $duckdb_pid -o rss=,vsz=,%cpu= 2>/dev/null)
        
        if [ -n "$stats" ]; then
            local rss=$(echo $stats | awk '{print $1}')
            local vsz=$(echo $stats | awk '{print $2}')
            local cpu=$(echo $stats | awk '{print $3}')
            
            # Calculate elapsed time
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            
            # Track maximum values
            if [ "$rss" -gt "$max_rss" ]; then
                max_rss=$rss
                echo "New Peak RSS: ${max_rss} KB at ${elapsed}s" | tee -a "$log_file"
            fi
            
            if [ "$vsz" -gt "$max_vsz" ]; then
                max_vsz=$vsz
                echo "New Peak VSZ: ${max_vsz} KB at ${elapsed}s" | tee -a "$log_file"
            fi
            
            # Track max CPU (handling decimal comparison)
            if command -v bc >/dev/null 2>&1; then
                if [ "$(echo "$cpu > $max_cpu" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
                    max_cpu=$cpu
                    echo "New Peak CPU: ${max_cpu}% at ${elapsed}s" | tee -a "$log_file"
                fi
            else
                # Fallback without bc
                if [ "${cpu%.*}" -gt "${max_cpu%.*}" ]; then
                    max_cpu=$cpu
                    echo "New Peak CPU: ${max_cpu}% at ${elapsed}s" | tee -a "$log_file"
                fi
            fi
            
            # Convert to MB for logging
            local rss_mb=$(awk "BEGIN {printf \"%.2f\", $rss / 1024}")
            local vsz_mb=$(awk "BEGIN {printf \"%.2f\", $vsz / 1024}")
            
            # Log current stats to memory CSV
            echo "$current_time,$elapsed,$rss,$vsz,$cpu,$rss_mb,$vsz_mb" >> "$memory_csv"
            
            # Real-time display (every 20 samples to avoid spam)
            sample_count=$((sample_count + 1))
            if [ $((sample_count % 20)) -eq 0 ]; then
                local status_msg="Sample $sample_count: RSS=${rss_mb}MB, VSZ=${vsz_mb}MB, CPU=${cpu}%, Elapsed=${elapsed}s"
                echo "$status_msg" | tee -a "$log_file"
                printf "\r$status_msg"
            fi
        else
            # Process might have ended, check if it's still running
            if ! kill -0 $duckdb_pid 2>/dev/null; then
                echo "Process ended at $(date)" | tee -a "$log_file"
                break
            fi
        fi
        
        sleep 0.5  # Sample every 0.5 seconds
    done
    
    echo  # New line after progress display
    
    # Wait for process to complete and capture exit code
    wait $duckdb_pid
    local exit_code=$?
    
    # Calculate total execution time
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    # Convert peak values to MB
    local max_rss_mb=$(awk "BEGIN {printf \"%.2f\", $max_rss / 1024}")
    local max_vsz_mb=$(awk "BEGIN {printf \"%.2f\", $max_vsz / 1024}")
    
    # Calculate average memory usage
    local avg_rss=0
    local avg_vsz=0
    if [ -s "$memory_csv" ]; then
        avg_rss=$(tail -n +2 "$memory_csv" | awk -F',' '{sum+=$3; count++} END {if(count>0) printf "%.2f", sum/count/1024; else print 0}')
        avg_vsz=$(tail -n +2 "$memory_csv" | awk -F',' '{sum+=$4; count++} END {if(count>0) printf "%.2f", sum/count/1024; else print 0}')
    fi
    
    # Log final results to both console and log file
    {
        echo ""
        echo "========================================"
        echo "FINAL RESULTS"
        echo "========================================"
        echo "DuckDB: $(basename "$duckdb_path")"
        echo "Query: $query_file"
        echo "Database: $database_file"
        echo "End Time: $(date)"
        echo "Execution time: ${total_time}s"
        echo "Exit code: $exit_code"
        echo "Peak RSS (Physical Memory): ${max_rss_mb} MB"
        echo "Peak VSZ (Virtual Memory): ${max_vsz_mb} MB"
        echo "Peak CPU Usage: ${max_cpu}%"
        echo "Average RSS: ${avg_rss} MB"
        echo "Average VSZ: ${avg_vsz} MB"
        echo "Total samples collected: $sample_count"
        echo "Memory CSV file: $memory_csv"
        echo "========================================"
    } | tee -a "$log_file"
    
    echo ""
    return $exit_code
}

# Function to run tests for a single query across all DuckDB executables
test_single_query() {
    local query_file="$1"
    local database_file="$2"
    
    echo "========================================"
    echo "Testing Query: $query_file"
    echo "Database: $database_file"
    echo "========================================"
    
    # Create summary file for this query - use full query path (in log directory)
    local query_path_safe=$(echo "$query_file" | sed 's|/|_|g' | sed 's|\.sql$||')
    local summary_file="log/summary_${query_path_safe}_$(date +%Y%m%d_%H%M%S).csv"
    local summary_log="log/summary_${query_path_safe}_$(date +%Y%m%d_%H%M%S).log"
    
    # Initialize summary files
    echo "DuckDB_Path,Query_File,Database_File,Execution_Time_s,Exit_Code,Peak_RSS_MB,Peak_VSZ_MB,Peak_CPU%,Avg_RSS_MB,Log_File,Memory_CSV" > "$summary_file"
    
    {
        echo "========================================"
        echo "QUERY SUMMARY LOG"
        echo "========================================"
        echo "Query File: $query_file"
        echo "Database File: $database_file"
        echo "Summary started at: $(date)"
        echo "========================================"
        echo ""
    } > "$summary_log"
    
    local successful_tests=0
    local failed_tests=0
    
    # Test each DuckDB executable with this query
    for duckdb_path in "${DUCKDB_PATHS[@]}"; do
        echo "Testing with DuckDB: $duckdb_path" | tee -a "$summary_log"
        
        if run_memory_test "$duckdb_path" "$query_file" "$database_file"; then
            successful_tests=$((successful_tests + 1))
            
            # Extract results from the most recent log file
            local duckdb_name=$(basename "$duckdb_path")
            
            local latest_log=$(find log -name "memory_${duckdb_name}_${query_path_safe}_*.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
            local latest_memory=$(find log -name "memory_${duckdb_name}_${query_path_safe}_*_memory.csv" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
            
            if [ -n "$latest_log" ]; then
                # Fixed extraction logic to match the actual log format
                local exec_time=$(grep "Execution time:" "$latest_log" | tail -1 | awk '{print $3}' | sed 's/s$//')
                local exit_code=$(grep "Exit code:" "$latest_log" | tail -1 | awk '{print $3}')
                
                # Fix: Extract the correct field for Peak RSS and VSZ
                local peak_rss=$(grep "Peak RSS (Physical Memory):" "$latest_log" | tail -1 | awk '{print $5}')
                local peak_vsz=$(grep "Peak VSZ (Virtual Memory):" "$latest_log" | tail -1 | awk '{print $5}')
                local peak_cpu=$(grep "Peak CPU Usage:" "$latest_log" | tail -1 | awk '{print $4}' | sed 's/%$//')
                local avg_rss=$(grep "Average RSS:" "$latest_log" | tail -1 | awk '{print $3}')
                
                # Add to CSV summary
                echo "$duckdb_path,$query_file,$database_file,$exec_time,$exit_code,$peak_rss,$peak_vsz,$peak_cpu,$avg_rss,$latest_log,$latest_memory" >> "$summary_file"
                
                # Add to log summary
                {
                    echo "Results for $duckdb_path:"
                    echo "  Execution time: ${exec_time:-N/A}s"
                    echo "  Exit code: ${exit_code:-N/A}"
                    echo "  Peak RSS: ${peak_rss:-N/A} MB"
                    echo "  Peak VSZ: ${peak_vsz:-N/A} MB"
                    echo "  Peak CPU: ${peak_cpu:-N/A}%"
                    echo "  Average RSS: ${avg_rss:-N/A} MB"
                    echo "  Log file: $latest_log"
                    echo "  Memory CSV: $latest_memory"
                    echo ""
                } | tee -a "$summary_log"
            fi
            
            echo "✅ Success" | tee -a "$summary_log"
        else
            failed_tests=$((failed_tests + 1))
            echo "❌ Failed" | tee -a "$summary_log"
        fi
        echo "" | tee -a "$summary_log"
    done
    
    # Final summary for this query
    local final_summary="Query Summary for $query_file:
  Successful tests: $successful_tests
  Failed/Skipped tests: $failed_tests
  Summary CSV saved to: $summary_file
  Summary log saved to: $summary_log"
    
    echo "$final_summary"
    echo "$final_summary" >> "$summary_log"
    
    # Add completion timestamp
    echo "" >> "$summary_log"
    echo "Summary completed at: $(date)" >> "$summary_log"
    echo "=======================================" >> "$summary_log"
    
    echo ""
    return 0
}

# Function to run all configured queries
run_all_queries() {
    echo "========================================"
    echo "Multi-DuckDB Memory Performance Test"
    echo "Running ALL Configured Queries"
    echo "========================================"
    echo "Number of queries: ${#QUERY_DATABASE_MAP[@]}"
    echo "Number of DuckDB executables: ${#DUCKDB_PATHS[@]}"
    echo ""
    
    # Create master summary file and log (in log directory)
    local master_summary="log/master_summary_$(date +%Y%m%d_%H%M%S).csv"
    local master_log="log/master_summary_$(date +%Y%m%d_%H%M%S).log"
    
    echo "Query_File,Database_File,DuckDB_Path,Execution_Time_s,Exit_Code,Peak_RSS_MB,Peak_VSZ_MB,Peak_CPU%,Avg_RSS_MB" > "$master_summary"
    
    {
        echo "========================================"
        echo "MASTER SUMMARY LOG"
        echo "========================================"
        echo "Test session started at: $(date)"
        echo "Number of queries: ${#QUERY_DATABASE_MAP[@]}"
        echo "Number of DuckDB executables: ${#DUCKDB_PATHS[@]}"
        echo "Current working directory: $(pwd)"
        echo "Log directory: $(pwd)/log"
        echo "Timeout: DISABLED (runs until completion)"
        echo "========================================"
        echo ""
    } > "$master_log"
    
    local total_tests=0
    local total_successful=0
    
    # Test each configured query
    for query_file in "${!QUERY_DATABASE_MAP[@]}"; do
        local database_file="${QUERY_DATABASE_MAP[$query_file]}"
        
        if [ -f "$query_file" ]; then
            echo "🚀 Testing query: $query_file" | tee -a "$master_log"
            test_single_query "$query_file" "$database_file"
            total_tests=$((total_tests + ${#DUCKDB_PATHS[@]}))
        else
            echo "⚠️  Query file not found: $query_file" | tee -a "$master_log"
        fi
    done
    
    local final_summary="======================================== 
FINAL SUMMARY - ALL QUERIES
========================================
Total configured queries: ${#QUERY_DATABASE_MAP[@]}
Total DuckDB executables: ${#DUCKDB_PATHS[@]}
Master summary saved to: $master_summary
Master log saved to: $master_log"
    
    echo "$final_summary"
    echo "$final_summary" >> "$master_log"
    
    # Show available result files (all in log directory)
    {
        echo ""
        echo "Generated files in log/ directory:"
        find log -name "summary_*.csv" -newer "$master_summary" 2>/dev/null | sort
        echo ""
        find log -name "memory_*.log" -newer "$master_summary" 2>/dev/null | wc -l | xargs -I {} echo "Generated {} individual log files"
        find log -name "*_memory.csv" -newer "$master_summary" 2>/dev/null | wc -l | xargs -I {} echo "Generated {} memory CSV files"
        find log -name "summary_*.log" -newer "$master_summary" 2>/dev/null | wc -l | xargs -I {} echo "Generated {} summary log files"
        echo ""
        echo "Total files in log directory: $(find log -type f | wc -l)"
        echo "Log directory size: $(du -sh log 2>/dev/null | cut -f1)"
        echo "Test session completed at: $(date)"
    } | tee -a "$master_log"
}

# Function to list configured queries and check their status
list_queries() {
    echo "Current working directory: $(pwd)"
    echo "Log directory: $(pwd)/log ($([ -d log ] && echo "exists" || echo "will be created"))"
    echo ""
    echo "Configured Query-Database Mappings:"
    echo "===================================="
    printf "%-4s %-40s %-15s %s\n" "OK?" "Query File (Full Path)" "Database" "Status"
    echo "---- ---------------------------------------- --------------- --------"
    
    for query_file in "${!QUERY_DATABASE_MAP[@]}"; do
        local database_file="${QUERY_DATABASE_MAP[$query_file]}"
        local query_status="❌ Missing"
        local db_status="❌ Missing"
        
        if [ -f "$query_file" ]; then
            query_status="✅ Found"
        fi
        
        if [ -f "$database_file" ]; then
            db_status="✅ Found"
        fi
        
        local overall_status="❌"
        if [ -f "$query_file" ] && [ -f "$database_file" ]; then
            overall_status="✅"
        fi
        
        printf "%-4s %-40s %-15s %s | %s\n" "$overall_status" "$query_file" "$database_file" "$query_status" "$db_status"
    done
    
    echo ""
    echo "DuckDB Executables:"
    echo "==================="
    for duckdb_path in "${DUCKDB_PATHS[@]}"; do
        local status="❌ Not found/executable"
        if [ -x "$duckdb_path" ]; then
            status="✅ Ready"
        fi
        printf "%-4s %s\n" "${status:0:2}" "$duckdb_path"
    done
    
    # Show existing log files if any
    if [ -d "log" ] && [ "$(find log -type f 2>/dev/null | wc -l)" -gt 0 ]; then
        echo ""
        echo "Existing files in log/ directory:"
        echo "=================================="
        find log -type f | head -10
        local total_files=$(find log -type f | wc -l)
        if [ "$total_files" -gt 10 ]; then
            echo "... and $((total_files - 10)) more files"
        fi
        echo "Total: $total_files files"
    fi
}

# Main execution function
main() {
    case "${1:-}" in
        --list|-l)
            list_queries
            ;;
        --help|-h)
            echo "Multi-DuckDB Memory Performance Testing Tool"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --list, -l     List all configured query-database mappings and their status"
            echo "  --help, -h     Show this help message"
            echo "  (no args)      Run all configured queries with all DuckDB executables"
            echo ""
            echo "Output Files (all in log/ directory):"
            echo "  log/memory_*_*.log           Individual test execution logs"
            echo "  log/*_memory.csv            Memory usage data over time"
            echo "  log/summary_*.csv           Per-query results summary (CSV)"
            echo "  log/summary_*.log           Per-query results summary (detailed log)"
            echo "  log/master_summary_*.csv    Overall results summary (CSV)"
            echo "  log/master_summary_*.log    Overall results summary (detailed log)"
            echo ""
            echo "Execution Policy:"
            echo "  - NO timeout - queries run until natural completion"
            echo "  - DuckDB threads: $NUM_THREADS"
            echo "  - Allowed logical CPU IDs: $CPU_LIST (Linux taskset)"
            echo "  - Direct DuckDB PID monitoring (taskset execs the process)"
            echo "  - Continuous memory sampling every 0.5 seconds"
            echo "  - Automatic cleanup on process termination"
            echo ""
            echo "Manual Termination:"
            echo "  Use Ctrl+C to stop the monitoring script"
            echo "  Individual DuckDB processes can be killed with: kill <PID>"
            echo ""
            echo "This script will test all configured queries with all configured DuckDB executables."
            echo "Results are saved in both CSV and detailed log files for comprehensive analysis."
            ;;
        "")
            # Default: run all queries
            validate_experiment_cpu_policy || exit 1
            run_all_queries
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"
