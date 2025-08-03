#!/bin/bash

# Professional ffuf automation script for massive scale processing
# Author: Security Automation Team
# Version: 2.0
# Description: Splits large domain files into manageable chunks and processes them with ffuf

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration variables
DOMAIN_FILE=""
CHUNK_SIZE=10000
OUTPUT_DIR=""
FFUF_THREADS=30
TARGET_PATH="/.DS_Store"
WORDLIST=""
MAX_PARALLEL_JOBS=5
VERBOSE=false
PRETTIFY_JSON=true

# Color codes for output
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m' # No Color

# Logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${OUTPUT_DIR}/ffuf_automation.log"
}

# Error handling function
error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Success message function
success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

# Warning message function
warn() {
    log "${YELLOW}WARNING: $1${NC}"
}

# Info message function
info() {
    log "${BLUE}INFO: $1${NC}"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 -d DOMAIN_FILE -o OUTPUT_DIR [OPTIONS]

Professional ffuf automation script for massive scale domain fuzzing

REQUIRED PARAMETERS:
    -d, --domains       Path to domain file (270M+ domains supported)
    -o, --output        Output directory for results

OPTIONAL PARAMETERS:
    -c, --chunk-size    Number of domains per chunk (default: 10000)
    -t, --threads       Number of ffuf threads (default: 30)
    -p, --path          Target path to fuzz (default: /.DS_Store)
    -w, --wordlist      Custom wordlist for fuzzing (optional)
    -j, --jobs          Max parallel jobs (default: 5)
    -v, --verbose       Enable verbose output
    --no-prettify       Disable JSON prettification
    -h, --help          Show this help message

EXAMPLES:
    # Basic usage for .DS_Store discovery
    $0 -d domains.txt -o ./results

    # Advanced usage with custom settings
    $0 -d huge_domains.csv -o ./scan_results -c 15000 -t 50 -j 8 -v

    # Custom path fuzzing with wordlist
    $0 -d domains.txt -o ./results -p "/admin" -w /path/to/wordlist.txt

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
    info "Validating prerequisites..."

    # Check if ffuf is installed
    if ! command -v ffuf &> /dev/null; then
        error_exit "ffuf is not installed or not in PATH"
    fi

    # Check if jq is installed for JSON prettification
    if [[ "$PRETTIFY_JSON" == true ]] && ! command -v jq &> /dev/null; then
        warn "jq not found. JSON prettification will be disabled"
        PRETTIFY_JSON=false
    fi

    # Check if parallel is available
    if ! command -v parallel &> /dev/null; then
        warn "GNU parallel not found. Using sequential processing"
    fi

    success "Prerequisites validation completed"
}

# Function to validate input parameters
validate_inputs() {
    info "Validating input parameters..."

    # Check domain file
    if [[ ! -f "$DOMAIN_FILE" ]]; then
        error_exit "Domain file '$DOMAIN_FILE' does not exist"
    fi

    # Check if domain file is readable
    if [[ ! -r "$DOMAIN_FILE" ]]; then
        error_exit "Domain file '$DOMAIN_FILE' is not readable"
    fi

    # Get file size for information
    local file_size=$(du -h "$DOMAIN_FILE" | cut -f1)
    info "Domain file size: $file_size"

    # Count total domains
    local total_domains=$(wc -l < "$DOMAIN_FILE")
    info "Total domains to process: $total_domains"

    # Check wordlist if provided
    if [[ -n "$WORDLIST" ]] && [[ ! -f "$WORDLIST" ]]; then
        error_exit "Wordlist file '$WORDLIST' does not exist"
    fi

    success "Input validation completed"
}

# Function to setup output directory structure
setup_output_directory() {
    info "Setting up output directory structure..."

    # Create main output directory
    mkdir -p "$OUTPUT_DIR"

    # Create subdirectories
    mkdir -p "$OUTPUT_DIR/chunks"
    mkdir -p "$OUTPUT_DIR/raw_results"
    mkdir -p "$OUTPUT_DIR/prettified_results"
    mkdir -p "$OUTPUT_DIR/logs"
    mkdir -p "$OUTPUT_DIR/summary"

    # Create processing status directory
    mkdir -p "$OUTPUT_DIR/status"

    success "Directory structure created"
}

# Function to split domain file into chunks
split_domain_file() {
    info "Splitting domain file into chunks of $CHUNK_SIZE domains..."

    local total_lines=$(wc -l < "$DOMAIN_FILE")
    local total_chunks=$(( (total_lines + CHUNK_SIZE - 1) / CHUNK_SIZE ))

    info "Creating $total_chunks chunks from $total_lines domains"

    # Split the file using split command with numeric suffixes
    split -l "$CHUNK_SIZE" -d --additional-suffix=.txt "$DOMAIN_FILE" "$OUTPUT_DIR/chunks/chunk_"

    # Count created chunks
    local created_chunks=$(ls "$OUTPUT_DIR/chunks/chunk_"*.txt | wc -l)

    success "Created $created_chunks chunk files"

    # Log chunk information
    echo "Chunk Information:" > "$OUTPUT_DIR/logs/chunk_info.log"
    ls -la "$OUTPUT_DIR/chunks/" >> "$OUTPUT_DIR/logs/chunk_info.log"
}

# Function to prettify JSON output
prettify_json() {
    local input_file="$1"
    local output_file="$2"

    if [[ "$PRETTIFY_JSON" == true ]] && [[ -f "$input_file" ]]; then
        if jq . "$input_file" > "$output_file" 2>/dev/null; then
            success "JSON prettified: $output_file"
        else
            warn "Failed to prettify JSON for $input_file"
            cp "$input_file" "$output_file"
        fi
    else
        cp "$input_file" "$output_file"
    fi
}

# Function to process a single chunk with ffuf
process_chunk() {
    local chunk_file="$1"
    local chunk_name=$(basename "$chunk_file" .txt)
    local raw_output="$OUTPUT_DIR/raw_results/${chunk_name}.json"
    local pretty_output="$OUTPUT_DIR/prettified_results/${chunk_name}_pretty.json"
    local status_file="$OUTPUT_DIR/status/${chunk_name}.status"

    info "Processing chunk: $chunk_name"

    # Mark chunk as processing
    echo "PROCESSING" > "$status_file"
    echo "Start time: $(date)" >> "$status_file"

    # Build ffuf command
    local ffuf_cmd="ffuf -c -w "$chunk_file" -o "$raw_output" -of json -v"

    if [[ -n "$WORDLIST" ]]; then
        # Use custom wordlist mode
        ffuf_cmd="ffuf -c -w "$WORDLIST" -u "https://FUZZ$TARGET_PATH" -o "$raw_output" -of json -v -t $FFUF_THREADS"
        # Need to process each domain in chunk with the wordlist
        while IFS= read -r domain; do
            [[ -z "$domain" ]] && continue
            local domain_clean=$(echo "$domain" | tr -d '
')
            ffuf -c -w "$WORDLIST" -u "https://${domain_clean}$TARGET_PATH" -o "${raw_output%.json}_${domain_clean//[^a-zA-Z0-9]/_}.json" -of json -v -t "$FFUF_THREADS" 2>&1 | tee -a "$OUTPUT_DIR/logs/${chunk_name}.log"
        done < "$chunk_file"
    else
        # Direct domain fuzzing mode
        ffuf_cmd="ffuf -c -w "$chunk_file" -u "https://FUZZ$TARGET_PATH" -o "$raw_output" -of json -v -t $FFUF_THREADS"

        # Execute ffuf command
        if eval "$ffuf_cmd" 2>&1 | tee -a "$OUTPUT_DIR/logs/${chunk_name}.log"; then
            echo "COMPLETED" > "$status_file"
            echo "End time: $(date)" >> "$status_file"
            success "Completed processing: $chunk_name"

            # Prettify JSON if enabled
            prettify_json "$raw_output" "$pretty_output"
        else
            echo "FAILED" > "$status_file"
            echo "End time: $(date)" >> "$status_file"
            echo "Error: ffuf command failed" >> "$status_file"
            warn "Failed processing: $chunk_name"
        fi
    fi
}

# Function to process all chunks in parallel
process_all_chunks() {
    info "Starting parallel processing of chunks..."

    local chunk_files=("$OUTPUT_DIR/chunks/chunk_"*.txt)
    local total_chunks=${#chunk_files[@]}

    info "Processing $total_chunks chunks with max $MAX_PARALLEL_JOBS parallel jobs"

    # Check if GNU parallel is available
    if command -v parallel &> /dev/null; then
        info "Using GNU parallel for processing"
        export -f process_chunk success warn info error_exit prettify_json
        export OUTPUT_DIR FFUF_THREADS TARGET_PATH WORDLIST PRETTIFY_JSON VERBOSE

        parallel -j "$MAX_PARALLEL_JOBS" process_chunk ::: "${chunk_files[@]}"
    else
        info "Using bash background jobs for processing"
        local active_jobs=0
        local job_pids=()

        for chunk_file in "${chunk_files[@]}"; do
            # Wait if we've reached max parallel jobs
            while [[ $active_jobs -ge $MAX_PARALLEL_JOBS ]]; do
                # Check for completed jobs
                for i in "${!job_pids[@]}"; do
                    if ! kill -0 "${job_pids[i]}" 2>/dev/null; then
                        unset "job_pids[i]"
                        ((active_jobs--))
                    fi
                done
                job_pids=("${job_pids[@]}")  # Reindex array
                sleep 1
            done

            # Start new job
            process_chunk "$chunk_file" &
            job_pids+=($!)
            ((active_jobs++))

            info "Started processing job for $(basename "$chunk_file") (PID: $!)"
        done

        # Wait for all remaining jobs to complete
        info "Waiting for all jobs to complete..."
        for pid in "${job_pids[@]}"; do
            wait "$pid"
        done
    fi

    success "All chunks processed"
}

# Function to generate summary report
generate_summary() {
    info "Generating summary report..."

    local summary_file="$OUTPUT_DIR/summary/processing_summary.txt"
    local json_summary="$OUTPUT_DIR/summary/processing_summary.json"

    # Count processed chunks
    local total_chunks=$(ls "$OUTPUT_DIR/chunks/chunk_"*.txt | wc -l)
    local completed_chunks=$(grep -l "COMPLETED" "$OUTPUT_DIR/status/"*.status | wc -l)
    local failed_chunks=$(grep -l "FAILED" "$OUTPUT_DIR/status/"*.status | wc -l)
    local processing_chunks=$(grep -l "PROCESSING" "$OUTPUT_DIR/status/"*.status | wc -l)

    # Generate text summary
    cat > "$summary_file" << EOF
FFUF AUTOMATION PROCESSING SUMMARY
==================================
Generated: $(date)
Domain File: $DOMAIN_FILE
Output Directory: $OUTPUT_DIR
Chunk Size: $CHUNK_SIZE
Target Path: $TARGET_PATH
Max Parallel Jobs: $MAX_PARALLEL_JOBS

PROCESSING STATISTICS:
---------------------
Total Chunks: $total_chunks
Completed: $completed_chunks
Failed: $failed_chunks
Still Processing: $processing_chunks

RESULTS LOCATION:
----------------
Raw Results: $OUTPUT_DIR/raw_results/
Prettified Results: $OUTPUT_DIR/prettified_results/
Logs: $OUTPUT_DIR/logs/
Status Files: $OUTPUT_DIR/status/

EOF

    # Add failed chunks details if any
    if [[ $failed_chunks -gt 0 ]]; then
        echo -e "
FAILED CHUNKS:" >> "$summary_file"
        echo "-------------" >> "$summary_file"
        grep -l "FAILED" "$OUTPUT_DIR/status/"*.status | while read -r status_file; do
            echo "$(basename "$status_file" .status)" >> "$summary_file"
        done
    fi

    # Generate JSON summary
    cat > "$json_summary" << EOF
{
    "summary": {
        "generated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
        "domain_file": "$DOMAIN_FILE",
        "output_directory": "$OUTPUT_DIR",
        "chunk_size": $CHUNK_SIZE,
        "target_path": "$TARGET_PATH",
        "max_parallel_jobs": $MAX_PARALLEL_JOBS
    },
    "statistics": {
        "total_chunks": $total_chunks,
        "completed": $completed_chunks,
        "failed": $failed_chunks,
        "processing": $processing_chunks
    },
    "results": {
        "raw_results": "$OUTPUT_DIR/raw_results/",
        "prettified_results": "$OUTPUT_DIR/prettified_results/",
        "logs": "$OUTPUT_DIR/logs/",
        "status_files": "$OUTPUT_DIR/status/"
    }
}
EOF

    success "Summary report generated: $summary_file"
    info "JSON summary generated: $json_summary"
}

# Function to cleanup temporary files
cleanup() {
    info "Performing cleanup..."

    # Remove empty result files
    find "$OUTPUT_DIR/raw_results/" -name "*.json" -size 0 -delete 2>/dev/null || true
    find "$OUTPUT_DIR/prettified_results/" -name "*.json" -size 0 -delete 2>/dev/null || true

    # Compress logs if they're large
    find "$OUTPUT_DIR/logs/" -name "*.log" -size +10M -exec gzip {} \; 2>/dev/null || true

    success "Cleanup completed"
}

# Function to monitor processing status
monitor_status() {
    while true; do
        local completed=$(grep -l "COMPLETED" "$OUTPUT_DIR/status/"*.status 2>/dev/null | wc -l)
        local failed=$(grep -l "FAILED" "$OUTPUT_DIR/status/"*.status 2>/dev/null | wc -l)
        local processing=$(grep -l "PROCESSING" "$OUTPUT_DIR/status/"*.status 2>/dev/null | wc -l)
        local total=$(ls "$OUTPUT_DIR/status/"*.status 2>/dev/null | wc -l)

        if [[ $total -eq 0 ]]; then
            sleep 5
            continue
        fi

        info "Status - Completed: $completed, Failed: $failed, Processing: $processing, Total: $total"

        if [[ $((completed + failed)) -eq $total ]]; then
            break
        fi

        sleep 10
    done
}

# Main execution function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domains)
                DOMAIN_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -c|--chunk-size)
                CHUNK_SIZE="$2"
                shift 2
                ;;
            -t|--threads)
                FFUF_THREADS="$2"
                shift 2
                ;;
            -p|--path)
                TARGET_PATH="$2"
                shift 2
                ;;
            -w|--wordlist)
                WORDLIST="$2"
                shift 2
                ;;
            -j|--jobs)
                MAX_PARALLEL_JOBS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-prettify)
                PRETTIFY_JSON=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$DOMAIN_FILE" ]] || [[ -z "$OUTPUT_DIR" ]]; then
        usage
        error_exit "Domain file (-d) and output directory (-o) are required"
    fi

    # Start processing
    info "Starting FFUF Automation Script"
    info "================================"

    validate_prerequisites
    validate_inputs
    setup_output_directory
    split_domain_file

    # Start monitoring in background if not verbose
    if [[ "$VERBOSE" != true ]]; then
        monitor_status &
        local monitor_pid=$!
    fi

    process_all_chunks

    # Kill monitor if running
    if [[ "$VERBOSE" != true ]] && [[ -n "${monitor_pid:-}" ]]; then
        kill "$monitor_pid" 2>/dev/null || true
    fi

    generate_summary
    cleanup

    success "FFUF automation completed successfully!"
    info "Check the summary report: $OUTPUT_DIR/summary/processing_summary.txt"
}

# Signal handlers for graceful shutdown
trap 'error_exit "Script interrupted by user"' INT TERM

# Execute main function with all arguments
main "$@"
