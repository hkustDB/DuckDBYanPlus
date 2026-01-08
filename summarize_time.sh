#!/bin/bash
# filepath: /dynamic-predicate-transfer/summarize_time.sh

# Check if directory argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <directory>"
    echo "Example: $0 job_agg_rewrite"
    exit 1
fi

DIR="$1"
OUTPUT_FILE="timing_summary.csv"

# Check if directory exists
if [ ! -d "$DIR" ]; then
    echo "Error: Directory '$DIR' does not exist"
    exit 1
fi

# Clear output file if it exists and write CSV header
echo "Query,Average_Time" > "$OUTPUT_FILE"

echo "Processing timing files in directory: $DIR"
echo "================================================"
echo "Query Name              Average Time"
echo "================================================"

# Find all time_*.txt files and process them
found_files=0
for file in "$DIR"/time_*.txt; do
    # Check if file exists (handles case when no files match)
    if [ ! -f "$file" ]; then
        continue
    fi
    
    found_files=$((found_files + 1))
    
    # Extract filename without path
    filename=$(basename "$file")
    
    # Extract only the part between underscores (e.g., time_1a0_6.txt -> 1a0_6)
    query_name=$(echo "$filename" | sed 's/^time_\(.*\)\.txt$/\1/')
    
    # Extract the average time (last line after "AVG")
    avg_time=$(tail -n 1 "$file" | grep -oP 'AVG\s+\K[\d.]+')
    
    # If avg_time is empty, try alternative extraction
    if [ -z "$avg_time" ]; then
        avg_time=$(tail -n 1 "$file" | awk '{print $NF}')
    fi
    
    # Print to console
    printf "%-23s %s\n" "$query_name" "$avg_time"
    
    # Append to CSV file
    echo "$query_name,$avg_time" >> "$OUTPUT_FILE"
done

echo "================================================"

if [ $found_files -eq 0 ]; then
    echo "No time_*.txt files found in directory: $DIR"
    rm -f "$OUTPUT_FILE"
    exit 1
fi

echo ""
echo "Summary saved to: $OUTPUT_FILE"
echo "Total files processed: $found_files"