#!/bin/bash

# Advanced FFUF Automation with tmux Dashboard
# Professional-grade automation with real-time monitoring interface
# Author: Security Research Team
# Version: 3.0 Advanced

set -euo pipefail

# Configuration
DOMAIN_FILE=""
OUTPUT_DIR=""
CHUNK_SIZE=10000
FFUF_THREADS=30
TARGET_PATH="/.DS_Store"
WORDLIST=""
MAX_PARALLEL_JOBS=5
VERBOSE=false
PRETTIFY_JSON=true
USE_TMUX_DASHBOARD=true
TMUX_SESSION_NAME="ffuf_automation"
DASHBOARD_REFRESH_RATE=2

# Color codes
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
PURPLE='[0;35m'
CYAN='[0;36m'
WHITE='[1;37m'
NC='[0m'

# UI Characters
CHECKMARK="✓"
CROSSMARK="✗"
ARROW="➤"
GEAR="⚙"
CHART="📊"
LIGHTNING="⚡"

# Global variables
TOTAL_CHUNKS=0
PROCESSED_CHUNKS=0
FAILED_CHUNKS=0
PROCESSING_CHUNKS=0
START_TIME=""
CURRENT_THROUGHPUT=0

# Logging functions with enhanced formatting
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${OUTPUT_DIR}/ffuf_automation.log" 2>/dev/null || echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

success() {
    log "${GREEN}${CHECKMARK} SUCCESS:${NC} $1"
}

error_exit() {
    log "${RED}${CROSSMARK} ERROR:${NC} $1"
    exit 1
}

warn() {
    log "${YELLOW}⚠ WARNING:${NC} $1"
}

info() {
    log "${BLUE}${ARROW} INFO:${NC} $1"
}

header() {
    echo -e "${PURPLE}${1}${NC}"
}

# Enhanced usage function with colors and examples
usage() {
    cat << EOF
${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}
${CYAN}║${NC} ${WHITE}Advanced FFUF Automation Suite v3.0${NC}                                ${CYAN}║${NC}
${CYAN}║${NC} Professional-grade massive scale domain processing with tmux dashboard  ${CYAN}║${NC}
${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}

${YELLOW}USAGE:${NC} $0 -d DOMAIN_FILE -o OUTPUT_DIR [OPTIONS]

${GREEN}REQUIRED PARAMETERS:${NC}
    ${BLUE}-d, --domains${NC}         Path to domain file (270M+ domains supported)
    ${BLUE}-o, --output${NC}          Output directory for results

${GREEN}OPTIONAL PARAMETERS:${NC}
    ${BLUE}-c, --chunk-size${NC}      Domains per chunk (default: 10000)
    ${BLUE}-t, --threads${NC}         ffuf threads (default: 30)
    ${BLUE}-p, --path${NC}            Target path (default: /.DS_Store)
    ${BLUE}-w, --wordlist${NC}        Custom wordlist for fuzzing
    ${BLUE}-j, --jobs${NC}            Max parallel jobs (default: 5)
    ${BLUE}-r, --refresh${NC}         Dashboard refresh rate in seconds (default: 2)
    ${BLUE}-v, --verbose${NC}         Enable verbose output
    ${BLUE}--no-prettify${NC}         Disable JSON prettification
    ${BLUE}--no-dashboard${NC}        Disable tmux dashboard
    ${BLUE}--tmux-session${NC}        Custom tmux session name
    ${BLUE}-h, --help${NC}            Show this help message

${YELLOW}EXAMPLES:${NC}
    ${GREEN}# Basic .DS_Store discovery with dashboard${NC}
    $0 -d domains.txt -o ./results

    ${GREEN}# Advanced configuration with custom dashboard refresh${NC}
    $0 -d huge_domains.csv -o ./scan_results -c 15000 -t 50 -j 8 -r 1 -v

    ${GREEN}# Custom path fuzzing without dashboard${NC}
    $0 -d domains.txt -o ./results -p "/admin" --no-dashboard

    ${GREEN}# Directory fuzzing with wordlist${NC}
    $0 -d domains.txt -o ./results -p "/FUZZ" -w /usr/share/wordlists/dirb/common.txt

EOF
}

# Check if tmux is available and create enhanced dashboard
check_tmux_availability() {
    if [[ "$USE_TMUX_DASHBOARD" == true ]]; then
        if ! command -v tmux &> /dev/null; then
            warn "tmux not found. Disabling dashboard mode"
            USE_TMUX_DASHBOARD=false
        else
            info "tmux found. Dashboard mode enabled"
        fi
    fi
}

# Create tmux dashboard with multiple panes
create_tmux_dashboard() {
    if [[ "$USE_TMUX_DASHBOARD" != true ]]; then
        return 0
    fi

    info "Creating advanced tmux dashboard..."

    # Kill existing session if it exists
    tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null || true

    # Create new session with main monitoring pane
    tmux new-session -d -s "$TMUX_SESSION_NAME" -x 120 -y 30

    # Rename main window
    tmux rename-window -t "$TMUX_SESSION_NAME:0" "FFUF-Monitor"

    # Create dashboard layout
    # Top left: Overall stats
    tmux send-keys -t "$TMUX_SESSION_NAME:0" "clear" C-m

    # Split vertically for main dashboard (70% left, 30% right)
    tmux split-window -t "$TMUX_SESSION_NAME:0" -h -p 30

    # Split the left pane horizontally (60% stats, 40% logs)
    tmux split-window -t "$TMUX_SESSION_NAME:0.0" -v -p 40

    # Split the right pane horizontally (50% processing status, 50% system resources)
    tmux split-window -t "$TMUX_SESSION_NAME:0.1" -v -p 50

    # Pane layout:
    # 0: Main stats dashboard (top-left)
    # 1: Real-time logs (bottom-left)  
    # 2: Processing status (top-right)
    # 3: System resources (bottom-right)

    # Start monitoring functions in each pane
    tmux send-keys -t "$TMUX_SESSION_NAME:0.0" "clear && echo 'Starting main dashboard...'" C-m
    tmux send-keys -t "$TMUX_SESSION_NAME:0.1" "clear && echo 'Initializing log monitor...'" C-m
    tmux send-keys -t "$TMUX_SESSION_NAME:0.2" "clear && echo 'Setting up processing monitor...'" C-m
    tmux send-keys -t "$TMUX_SESSION_NAME:0.3" "clear && echo 'Loading system monitor...'" C-m

    # Create additional windows for specific monitoring
    tmux new-window -t "$TMUX_SESSION_NAME" -n "Active-Jobs"
    tmux new-window -t "$TMUX_SESSION_NAME" -n "Results-View"

    success "tmux dashboard created: session '$TMUX_SESSION_NAME'"
}

# Update main dashboard statistics
update_main_dashboard() {
    if [[ "$USE_TMUX_DASHBOARD" != true ]]; then
        return 0
    fi

    local current_time=$(date '+%H:%M:%S')
    local elapsed_time=""
    if [[ -n "$START_TIME" ]]; then
        elapsed_time=$(( $(date +%s) - START_TIME ))
    fi

    local eta="Calculating..."
    if [[ $PROCESSED_CHUNKS -gt 0 ]] && [[ $elapsed_time -gt 0 ]]; then
        local rate=$(( PROCESSED_CHUNKS * 60 / elapsed_time ))
        local remaining=$(( TOTAL_CHUNKS - PROCESSED_CHUNKS ))
        if [[ $rate -gt 0 ]]; then
            eta="$(( remaining / rate )) min"
        fi
    fi

    local progress_percentage=0
    if [[ $TOTAL_CHUNKS -gt 0 ]]; then
        progress_percentage=$(( PROCESSED_CHUNKS * 100 / TOTAL_CHUNKS ))
    fi

    # Create progress bar
    local bar_width=40
    local filled=$(( progress_percentage * bar_width / 100 ))
    local empty=$(( bar_width - filled ))
    local progress_bar=""

    for ((i=0; i<filled; i++)); do
        progress_bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        progress_bar+="░"
    done

    local dashboard_content=$(cat << EOF
╔══════════════════════════════════════════════════════════════════╗
║                    🚀 FFUF AUTOMATION DASHBOARD                  ║
╠══════════════════════════════════════════════════════════════════╣
║ ${LIGHTNING} Status: RUNNING                Time: $current_time          ║
║ ${GEAR} Session: $TMUX_SESSION_NAME                                        ║
╠══════════════════════════════════════════════════════════════════╣
║ PROGRESS                                                         ║
║ [$progress_bar] $progress_percentage%       ║
║                                                                  ║
║ ${CHART} STATISTICS                                                   ║
║ ├─ Total chunks:      $TOTAL_CHUNKS                                    ║
║ ├─ Processed:         $PROCESSED_CHUNKS                                ║
║ ├─ Currently active:  $PROCESSING_CHUNKS                               ║
║ └─ Failed:            $FAILED_CHUNKS                                   ║
║                                                                  ║
║ ⏱ TIMING                                                          ║
║ ├─ Elapsed:           ${elapsed_time}s                                  ║
║ ├─ ETA:               $eta                             ║
║ └─ Throughput:        $CURRENT_THROUGHPUT chunks/min                   ║
║                                                                  ║
║ 📁 OUTPUT                                                         ║
║ └─ Directory:         $OUTPUT_DIR    ║
╚══════════════════════════════════════════════════════════════════╝

Press Ctrl+B then 'd' to detach from dashboard
Use 'tmux attach -t $TMUX_SESSION_NAME' to reattach
EOF
)

    # Send dashboard content to main pane
    tmux send-keys -t "$TMUX_SESSION_NAME:0.0" "clear" C-m
    echo "$dashboard_content" | while IFS= read -r line; do
        tmux send-keys -t "$TMUX_SESSION_NAME:0.0" "echo '$line'" C-m
    done
}

# Update processing status pane
update_processing_status() {
    if [[ "$USE_TMUX_DASHBOARD" != true ]]; then
        return 0
    fi

    local status_content=$(cat << EOF
╔═══════════════════════════════╗
║       ACTIVE PROCESSES        ║
╠═══════════════════════════════╣
EOF
)

    # Get currently processing chunks
    if [[ -d "$OUTPUT_DIR/status" ]]; then
        local active_chunks=$(find "$OUTPUT_DIR/status" -name "*.status" -exec grep -l "PROCESSING" {} \; 2>/dev/null | head -10)

        if [[ -n "$active_chunks" ]]; then
            echo "$active_chunks" | while read -r status_file; do
                local chunk_name=$(basename "$status_file" .status)
                status_content+="║ ${GEAR} $chunk_name"$'
'
            done
        else
            status_content+="║ No active processes"$'
'
        fi
    fi

    status_content+="╚═══════════════════════════════╝"

    tmux send-keys -t "$TMUX_SESSION_NAME:0.2" "clear" C-m
    echo "$status_content" | while IFS= read -r line; do
        tmux send-keys -t "$TMUX_SESSION_NAME:0.2" "echo '$line'" C-m
    done
}

# Update system resources pane
update_system_resources() {
    if [[ "$USE_TMUX_DASHBOARD" != true ]]; then
        return 0
    fi

    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    local memory_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}' 2>/dev/null || echo "N/A")
    local disk_usage=$(df -h "$OUTPUT_DIR" 2>/dev/null | awk 'NR==2{print $5}' | cut -d'%' -f1 || echo "N/A")
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | cut -d',' -f1 2>/dev/null || echo "N/A")

    local resources_content=$(cat << EOF
╔═══════════════════════════════╗
║      SYSTEM RESOURCES         ║
╠═══════════════════════════════╣
║ 🖥️  CPU Usage:    ${cpu_usage}%         ║
║ 🧠 Memory:       ${memory_usage}%         ║
║ 💾 Disk:         ${disk_usage}%         ║
║ ⚖️  Load Avg:     ${load_avg}           ║
║                               ║
║ 📊 PROCESS STATS              ║
║ ├─ Max parallel:  $MAX_PARALLEL_JOBS           ║
║ ├─ Threads/job:   $FFUF_THREADS           ║
║ └─ Chunk size:    $CHUNK_SIZE        ║
╚═══════════════════════════════╝
EOF
)

    tmux send-keys -t "$TMUX_SESSION_NAME:0.3" "clear" C-m
    echo "$resources_content" | while IFS= read -r line; do
        tmux send-keys -t "$TMUX_SESSION_NAME:0.3" "echo '$line'" C-m
    done
}

# Update logs pane with real-time log streaming
update_logs_pane() {
    if [[ "$USE_TMUX_DASHBOARD" != true ]]; then
        return 0
    fi

    local log_file="$OUTPUT_DIR/ffuf_automation.log"
    if [[ -f "$log_file" ]]; then
        tmux send-keys -t "$TMUX_SESSION_NAME:0.1" "clear" C-m
        tmux send-keys -t "$TMUX_SESSION_NAME:0.1" "echo '═══════════════ RECENT LOGS ═══════════════'" C-m
        tmux send-keys -t "$TMUX_SESSION_NAME:0.1" "tail -n 15 '$log_file'" C-m
    fi
}

# Background dashboard updater
start_dashboard_updater() {
    if [[ "$USE_TMUX_DASHBOARD" != true ]]; then
        return 0
    fi

    (
        while tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null; do
            # Update statistics
            if [[ -d "$OUTPUT_DIR/status" ]]; then
                PROCESSED_CHUNKS=$(find "$OUTPUT_DIR/status" -name "*.status" -exec grep -l "COMPLETED" {} \; 2>/dev/null | wc -l)
                FAILED_CHUNKS=$(find "$OUTPUT_DIR/status" -name "*.status" -exec grep -l "FAILED" {} \; 2>/dev/null | wc -l)
                PROCESSING_CHUNKS=$(find "$OUTPUT_DIR/status" -name "*.status" -exec grep -l "PROCESSING" {} \; 2>/dev/null | wc -l)

                # Calculate throughput
                if [[ -n "$START_TIME" ]]; then
                    local elapsed=$(( $(date +%s) - START_TIME ))
                    if [[ $elapsed -gt 0 ]]; then
                        CURRENT_THROUGHPUT=$(( PROCESSED_CHUNKS * 60 / elapsed ))
                    fi
                fi
            fi

            # Update all dashboard components
            update_main_dashboard
            update_processing_status
            update_system_resources
            update_logs_pane

            sleep "$DASHBOARD_REFRESH_RATE"
        done
    ) &

    local updater_pid=$!
    echo "$updater_pid" > "$OUTPUT_DIR/dashboard_updater.pid"
    success "Dashboard updater started (PID: $updater_pid)"
}

# Enhanced directory setup with better organization
setup_output_directory() {
    info "Setting up enhanced output directory structure..."

    mkdir -p "$OUTPUT_DIR"/{chunks,raw_results,prettified_results,logs,status,summary,tmp,dashboard}

    # Create dashboard info file
    cat > "$OUTPUT_DIR/dashboard/info.txt" << EOF
Dashboard Session: $TMUX_SESSION_NAME
Started: $(date)
Refresh Rate: ${DASHBOARD_REFRESH_RATE}s
EOF

    success "Enhanced directory structure created"
}

# Enhanced validation with more checks
validate_prerequisites() {
    info "Validating prerequisites..."

    local missing_tools=()

    # Check ffuf
    if ! command -v ffuf &> /dev/null; then
        missing_tools+=("ffuf")
    fi

    # Check jq for JSON prettification
    if [[ "$PRETTIFY_JSON" == true ]] && ! command -v jq &> /dev/null; then
        warn "jq not found. JSON prettification will be disabled"
        PRETTIFY_JSON=false
    fi

    # Check parallel
    if ! command -v parallel &> /dev/null; then
        warn "GNU parallel not found. Using sequential processing"
    fi

    # Check tmux for dashboard
    check_tmux_availability

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error_exit "Missing required tools: ${missing_tools[*]}"
    fi

    success "Prerequisites validation completed"
}

# Enhanced chunk processing with better monitoring
process_chunk() {
    local chunk_file="$1"
    local chunk_name=$(basename "$chunk_file" .txt)
    local raw_output="$OUTPUT_DIR/raw_results/${chunk_name}.json"
    local pretty_output="$OUTPUT_DIR/prettified_results/${chunk_name}_pretty.json"
    local status_file="$OUTPUT_DIR/status/${chunk_name}.status"
    local chunk_log="$OUTPUT_DIR/logs/${chunk_name}.log"

    # Create status file
    cat > "$status_file" << EOF
PROCESSING
Chunk: $chunk_name
Start time: $(date)
PID: $$
EOF

    local ffuf_cmd="ffuf -c -w "$chunk_file" -u "https://FUZZ$TARGET_PATH" -o "$raw_output" -of json -v -t $FFUF_THREADS"

    if [[ -n "$WORDLIST" ]]; then
        ffuf_cmd="ffuf -c -w "$WORDLIST" -u "https://DOMAIN$TARGET_PATH" -o "$raw_output" -of json -v -t $FFUF_THREADS"
    fi

    # Execute ffuf with enhanced logging
    if eval "$ffuf_cmd" &> "$chunk_log"; then
        cat >> "$status_file" << EOF
COMPLETED
End time: $(date)
Success: true
EOF
        # Prettify JSON if enabled
        if [[ "$PRETTIFY_JSON" == true ]] && [[ -f "$raw_output" ]]; then
            jq . "$raw_output" > "$pretty_output" 2>/dev/null || cp "$raw_output" "$pretty_output"
        fi
    else
        cat >> "$status_file" << EOF
FAILED
End time: $(date)
Error: ffuf command failed
EOF
    fi
}

# Main processing with enhanced monitoring
process_all_chunks() {
    info "Starting enhanced parallel processing..."

    START_TIME=$(date +%s)
    local chunk_files=("$OUTPUT_DIR/chunks/chunk_"*.txt)
    TOTAL_CHUNKS=${#chunk_files[@]}

    info "Processing $TOTAL_CHUNKS chunks with max $MAX_PARALLEL_JOBS parallel jobs"

    # Start dashboard if enabled
    if [[ "$USE_TMUX_DASHBOARD" == true ]]; then
        create_tmux_dashboard
        start_dashboard_updater

        # Attach to dashboard
        info "Attaching to tmux dashboard..."
        tmux attach -t "$TMUX_SESSION_NAME"
    else
        # Use GNU parallel or bash background jobs
        if command -v parallel &> /dev/null; then
            export -f process_chunk
            export OUTPUT_DIR FFUF_THREADS TARGET_PATH WORDLIST PRETTIFY_JSON
            parallel -j "$MAX_PARALLEL_JOBS" process_chunk ::: "${chunk_files[@]}"
        else
            local active_jobs=0
            local job_pids=()

            for chunk_file in "${chunk_files[@]}"; do
                while [[ $active_jobs -ge $MAX_PARALLEL_JOBS ]]; do
                    for i in "${!job_pids[@]}"; do
                        if ! kill -0 "${job_pids[i]}" 2>/dev/null; then
                            unset "job_pids[i]"
                            ((active_jobs--))
                        fi
                    done
                    job_pids=("${job_pids[@]}")
                    sleep 1
                done

                process_chunk "$chunk_file" &
                job_pids+=($!)
                ((active_jobs++))
            done

            for pid in "${job_pids[@]}"; do
                wait "$pid"
            done
        fi
    fi

    success "All chunks processed"
}

# Enhanced cleanup
cleanup() {
    info "Performing enhanced cleanup..."

    # Stop dashboard updater
    if [[ -f "$OUTPUT_DIR/dashboard_updater.pid" ]]; then
        local updater_pid=$(cat "$OUTPUT_DIR/dashboard_updater.pid")
        kill "$updater_pid" 2>/dev/null || true
        rm -f "$OUTPUT_DIR/dashboard_updater.pid"
    fi

    # Clean up tmux session
    if [[ "$USE_TMUX_DASHBOARD" == true ]]; then
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null || true
    fi

    # Remove empty files
    find "$OUTPUT_DIR" -name "*.json" -size 0 -delete 2>/dev/null || true
    find "$OUTPUT_DIR" -name "*.log" -size 0 -delete 2>/dev/null || true

    success "Enhanced cleanup completed"
}

# Parse arguments with enhanced validation
parse_arguments() {
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
            -r|--refresh)
                DASHBOARD_REFRESH_RATE="$2"
                shift 2
                ;;
            --tmux-session)
                TMUX_SESSION_NAME="$2"
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
            --no-dashboard)
                USE_TMUX_DASHBOARD=false
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

    if [[ -z "$DOMAIN_FILE" ]] || [[ -z "$OUTPUT_DIR" ]]; then
        usage
        error_exit "Domain file (-d) and output directory (-o) are required"
    fi
}

# Signal handlers
trap 'cleanup; error_exit "Script interrupted by user"' INT TERM

# Main execution
main() {
    # Display header
    clear
    header "╔══════════════════════════════════════════════════════════════════════════╗"
    header "║                    🚀 ADVANCED FFUF AUTOMATION v3.0                     ║"
    header "║                 Professional Massive Scale Processing                   ║"
    header "╚══════════════════════════════════════════════════════════════════════════╝"
    echo

    parse_arguments "$@"

    info "Starting Advanced FFUF Automation..."

    validate_prerequisites
    setup_output_directory

    # Validate inputs
    if [[ ! -f "$DOMAIN_FILE" ]]; then
        error_exit "Domain file '$DOMAIN_FILE' does not exist"
    fi

    local file_size=$(du -h "$DOMAIN_FILE" | cut -f1)
    local total_domains=$(wc -l < "$DOMAIN_FILE")
    info "Processing domain file: $file_size ($total_domains domains)"

    # Split domain file
    info "Splitting into chunks of $CHUNK_SIZE domains..."
    split -l "$CHUNK_SIZE" -d --additional-suffix=.txt "$DOMAIN_FILE" "$OUTPUT_DIR/chunks/chunk_"

    # Process chunks
    process_all_chunks

    # Generate final summary
    info "Generating final summary..."
    local completed=$(find "$OUTPUT_DIR/status" -name "*.status" -exec grep -l "COMPLETED" {} \; 2>/dev/null | wc -l)
    local failed=$(find "$OUTPUT_DIR/status" -name "*.status" -exec grep -l "FAILED" {} \; 2>/dev/null | wc -l)

    cat > "$OUTPUT_DIR/summary/final_report.txt" << EOF
ADVANCED FFUF AUTOMATION - FINAL REPORT
========================================
Completion Time: $(date)
Total Processing Time: $(( $(date +%s) - START_TIME ))s

STATISTICS:
- Total Chunks: $TOTAL_CHUNKS
- Completed: $completed
- Failed: $failed
- Success Rate: $(( completed * 100 / TOTAL_CHUNKS ))%

CONFIGURATION:
- Domain File: $DOMAIN_FILE
- Output Directory: $OUTPUT_DIR
- Chunk Size: $CHUNK_SIZE
- Target Path: $TARGET_PATH
- Parallel Jobs: $MAX_PARALLEL_JOBS
- ffuf Threads: $FFUF_THREADS

RESULTS LOCATION:
- Raw Results: $OUTPUT_DIR/raw_results/
- Prettified Results: $OUTPUT_DIR/prettified_results/
- Logs: $OUTPUT_DIR/logs/
- Dashboard Info: $OUTPUT_DIR/dashboard/
EOF

    cleanup

    success "Advanced FFUF automation completed successfully!"
    success "Final report: $OUTPUT_DIR/summary/final_report.txt"

    if [[ "$USE_TMUX_DASHBOARD" == true ]]; then
        info "You can reattach to the dashboard later with: tmux attach -t $TMUX_SESSION_NAME"
    fi
}

# Execute main function
main "$@"
