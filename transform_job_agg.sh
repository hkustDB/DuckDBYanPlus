#!/bin/bash

# Enhanced script to transform all MIN aggregate queries in a directory
# Usage: ./transform_all_queries_enhanced.sh input_directory output_directory

if [ $# -ne 2 ]; then
    echo "Usage: $0 input_directory output_directory"
    exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory $INPUT_DIR not found"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to extract MIN columns from SQL file
extract_min_columns() {
    local file="$1"
    
    # Use awk to properly parse MIN expressions across multiple lines
    awk '
    BEGIN { in_select = 0; select_text = "" }
    
    /^SELECT/ { in_select = 1; select_text = $0; next }
    
    in_select && /^FROM/ { in_select = 0; print select_text; next }
    
    in_select { select_text = select_text " " $0 }
    
    END { if (in_select) print select_text }
    ' "$file" | awk '
    {
        text = $0
        while (match(text, /MIN\([[:space:]]*[^)]+[[:space:]]*\)/)) {
            value = substr(text, RSTART + 4, RLENGTH - 5)
            sub(/^[[:space:]]*/, "", value)
            sub(/[[:space:]]*$/, "", value)
            print value
            text = substr(text, RSTART + RLENGTH)
        }
    }
    '
}

# Function to transform a single query file
transform_query_enhanced() {
    local input_file="$1"
    local output_file="$2"
    
    echo "Transforming: $(basename "$input_file")"
    
    # Extract MIN columns
    local min_cols=($(extract_min_columns "$input_file"))
    
    if [ ${#min_cols[@]} -eq 0 ]; then
        echo "  No MIN aggregates found, copying original file"
        cp "$input_file" "$output_file"
        return
    fi
    
    echo "  Found MIN columns: ${min_cols[*]}"
    
    # Build new SELECT clause
    local new_select="SELECT "
    local group_by_cols=""
    
    for i in "${!min_cols[@]}"; do
        local col="${min_cols[$i]}"
        
        if [ $i -gt 0 ]; then
            new_select="$new_select,\n       "
            group_by_cols="$group_by_cols, "
        fi
        
        new_select="$new_select$col"
        group_by_cols="$group_by_cols$col"
    done
    
    # Keep the aggregate spelling used by the Yan+ JOB workload.
    new_select="$new_select,\n       SUM(1) AS record_count"
    
    # Create the transformed query
    {
        echo -e "$new_select"
        
        # Copy every predicate. Removing the last physical line used to drop a
        # join condition from files without a trailing blank line (1b and 8a).
        awk '
        /^FROM/ { copy = 1 }
        copy { lines[++count] = $0 }
        END {
            while (count > 0 && lines[count] ~ /^[[:space:]]*$/) {
                count--
            }
            sub(/[[:space:]]*;[[:space:]]*$/, "", lines[count])
            for (line = 1; line <= count; line++) {
                print lines[line]
            }
        }
        ' "$input_file"
        echo "GROUP BY $group_by_cols"
        
        # Add semicolon if original had one
        if tail -n1 "$input_file" | grep -q ';'; then
            echo ";"
        fi
        
    } > "$output_file"
    
    echo "  Transformation completed"
}

# Process all SQL files
total_files=0
transformed_files=0

while read -r sql_file; do
    total_files=$((total_files + 1))
    
    # Get relative path from input directory
    relative_path=${sql_file#"${INPUT_DIR%/}"/}
    
    # Create corresponding output file path
    output_file="$OUTPUT_DIR/$relative_path"
    
    # Create output subdirectories if needed
    output_subdir=$(dirname "$output_file")
    mkdir -p "$output_subdir"
    
    # Transform the query
    transform_query_enhanced "$sql_file" "$output_file"
    
    # Check if transformation actually changed the file
    if ! diff -q "$sql_file" "$output_file" > /dev/null 2>&1; then
        transformed_files=$((transformed_files + 1))
    fi
done < <(find "$INPUT_DIR" -name "*.sql" -type f | sort)

echo ""
echo "============================================="
echo "Transformation Summary:"
echo "  Input directory: $INPUT_DIR"
echo "  Output directory: $OUTPUT_DIR"
echo "  Files processed: $total_files"
echo "  Files transformed: $transformed_files"
echo "============================================="
echo ""
echo "Transformed files:"
while read -r file; do
    echo "  ${file#"${OUTPUT_DIR%/}"/}"
done < <(find "$OUTPUT_DIR" -name "*.sql" -type f | sort)
