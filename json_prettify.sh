#!/bin/bash

# JSON Prettifier Utility Script
# Standalone script for prettifying ffuf JSON results

set -euo pipefail

# Color codes
GREEN='[0;32m'
RED='[0;31m'
YELLOW='[1;33m'
NC='[0m'

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] input_file [output_file]

Prettify JSON files (especially ffuf results)

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -f, --force     Overwrite output file if it exists
    -d, --dir       Process all JSON files in directory
    -r, --recursive Process directories recursively

EXAMPLES:
    # Prettify single file
    $0 results.json results_pretty.json

    # Prettify all JSON files in directory
    $0 -d /path/to/json/files/

    # Recursive processing
    $0 -r -d /path/to/results/

EOF
}

# Logging functions
log_info() {
    echo -e "[$(date '+%H:%M:%S')] ${GREEN}INFO:${NC} $1"
}

log_error() {
    echo -e "[$(date '+%H:%M:%S')] ${RED}ERROR:${NC} $1" >&2
}

log_warn() {
    echo -e "[$(date '+%H:%M:%S')] ${YELLOW}WARN:${NC} $1"
}

# Function to prettify a single JSON file
prettify_json_file() {
    local input_file="$1"
    local output_file="$2"
    local force="$3"
    local verbose="$4"

    # Check if input file exists
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file '$input_file' does not exist"
        return 1
    fi

    # Check if output file exists and force flag is not set
    if [[ -f "$output_file" ]] && [[ "$force" != "true" ]]; then
        log_warn "Output file '$output_file' exists. Use -f to overwrite"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq to prettify JSON"
        return 1
    fi

    # Prettify the JSON
    if jq . "$input_file" > "$output_file" 2>/dev/null; then
        if [[ "$verbose" == "true" ]]; then
            log_info "Successfully prettified: $input_file -> $output_file"
        fi
        return 0
    else
        log_error "Failed to prettify JSON file: $input_file"
        # Try to copy the original file if JSON parsing failed
        cp "$input_file" "$output_file" 2>/dev/null || true
        return 1
    fi
}

# Function to process directory
process_directory() {
    local dir_path="$1"
    local recursive="$2"
    local force="$3"
    local verbose="$4"

    if [[ ! -d "$dir_path" ]]; then
        log_error "Directory '$dir_path' does not exist"
        return 1
    fi

    local find_cmd="find '$dir_path'"
    if [[ "$recursive" != "true" ]]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi
    find_cmd="$find_cmd -name '*.json' -type f"

    local processed=0
    local failed=0

    while IFS= read -r -d '' json_file; do
        local dir_name=$(dirname "$json_file")
        local base_name=$(basename "$json_file" .json)
        local pretty_file="$dir_name/${base_name}_pretty.json"

        if prettify_json_file "$json_file" "$pretty_file" "$force" "$verbose"; then
            ((processed++))
        else
            ((failed++))
        fi
    done < <(eval "$find_cmd -print0")

    log_info "Processed: $processed files, Failed: $failed files"
}

# Main function
main() {
    local input_file=""
    local output_file=""
    local force="false"
    local verbose="false"
    local directory="false"
    local recursive="false"
    local dir_path=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -d|--dir)
                directory="true"
                if [[ -n "${2:-}" ]] && [[ "$2" != -* ]]; then
                    dir_path="$2"
                    shift 2
                else
                    dir_path="."
                    shift
                fi
                ;;
            -r|--recursive)
                recursive="true"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$input_file" ]]; then
                    input_file="$1"
                elif [[ -z "$output_file" ]]; then
                    output_file="$1"
                else
                    log_error "Too many arguments"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Directory processing mode
    if [[ "$directory" == "true" ]]; then
        if [[ -z "$dir_path" ]]; then
            dir_path="."
        fi
        log_info "Processing JSON files in directory: $dir_path"
        if [[ "$recursive" == "true" ]]; then
            log_info "Recursive mode enabled"
        fi
        process_directory "$dir_path" "$recursive" "$force" "$verbose"
        return $?
    fi

    # Single file processing mode
    if [[ -z "$input_file" ]]; then
        log_error "Input file is required"
        usage
        exit 1
    fi

    if [[ -z "$output_file" ]]; then
        # Generate output filename
        local dir_name=$(dirname "$input_file")
        local base_name=$(basename "$input_file" .json)
        output_file="$dir_name/${base_name}_pretty.json"
    fi

    if [[ "$verbose" == "true" ]]; then
        log_info "Input file: $input_file"
        log_info "Output file: $output_file"
    fi

    prettify_json_file "$input_file" "$output_file" "$force" "$verbose"
}

# Execute main function with all arguments
main "$@"
