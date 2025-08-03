#!/bin/bash

# FFUF Automation Setup Manager with GUI
# Interactive setup and configuration using whiptail/dialog
# Version: 1.0

set -euo pipefail

# Colors for non-whiptail output
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m'

# Configuration variables
DIALOG_CMD=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/ffuf_config.conf"

# Detect dialog command (whiptail or dialog)
detect_dialog_cmd() {
    if command -v whiptail &> /dev/null; then
        DIALOG_CMD="whiptail"
    elif command -v dialog &> /dev/null; then
        DIALOG_CMD="dialog"
    else
        echo -e "${RED}Error: Neither whiptail nor dialog found. Please install one of them.${NC}"
        echo "Ubuntu/Debian: sudo apt install whiptail"
        echo "CentOS/RHEL: sudo yum install newt"
        exit 1
    fi
}

# Show welcome screen
show_welcome() {
    $DIALOG_CMD --title "FFUF Automation Setup" --msgbox "Welcome to the Advanced FFUF Automation Setup Manager!

This tool will help you configure and run your massive scale domain processing with an interactive interface.

Features:
• Interactive configuration
• Prerequisites checking
• Sample data generation
• Real-time monitoring setup
• tmux dashboard configuration" 16 70
}

# Check prerequisites with visual feedback
check_prerequisites() {
    local results=""
    local missing_count=0

    # Create a temporary file for results
    local temp_file=$(mktemp)

    {
        echo "10"
        echo "# Checking ffuf installation..."
        sleep 1

        if command -v ffuf &> /dev/null; then
            echo "# ✓ ffuf found"
            results+="ffuf: ✓ Installed\n"
        else
            echo "# ✗ ffuf not found"
            results+="ffuf: ✗ Missing\n"
            ((missing_count++))
        fi

        echo "30"
        echo "# Checking jq installation..."
        sleep 1

        if command -v jq &> /dev/null; then
            echo "# ✓ jq found"
            results+="jq: ✓ Installed\n"
        else
            echo "# ✗ jq not found"
            results+="jq: ✗ Missing (JSON prettification disabled)\n"
        fi

        echo "50"
        echo "# Checking tmux installation..."
        sleep 1

        if command -v tmux &> /dev/null; then
            echo "# ✓ tmux found"
            results+="tmux: ✓ Installed\n"
        else
            echo "# ✗ tmux not found"
            results+="tmux: ✗ Missing (Dashboard disabled)\n"
        fi

        echo "70"
        echo "# Checking GNU parallel..."
        sleep 1

        if command -v parallel &> /dev/null; then
            echo "# ✓ GNU parallel found"
            results+="GNU parallel: ✓ Installed\n"
        else
            echo "# ✗ GNU parallel not found"
            results+="GNU parallel: ✗ Missing (Will use bash jobs)\n"
        fi

        echo "90"
        echo "# Checking script permissions..."
        sleep 1

        if [[ -x "$SCRIPT_DIR/ffuf_automation_advanced.sh" ]]; then
            echo "# ✓ Scripts are executable"
            results+="Script permissions: ✓ Executable\n"
        else
            echo "# ! Making scripts executable..."
            chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
            results+="Script permissions: ✓ Fixed\n"
        fi

        echo "100"
        echo "# Prerequisites check complete"
        sleep 1

    } | $DIALOG_CMD --title "Prerequisites Check" --gauge "Initializing..." 8 60 0

    # Show results
    if [[ $missing_count -eq 0 ]]; then
        $DIALOG_CMD --title "Prerequisites Check - Results" --msgbox "✓ All prerequisites satisfied!\n\n$results\nYou can proceed with the full automation setup." 16 60
        return 0
    else
        $DIALOG_CMD --title "Prerequisites Check - Results" --msgbox "⚠ Some prerequisites are missing:\n\n$results\nInstallation instructions:\n\nffuf: go install github.com/ffuf/ffuf@latest\njq: sudo apt install jq\ntmux: sudo apt install tmux\nparallel: sudo apt install parallel" 20 70
        return 1
    fi
}

# Configure ffuf settings
configure_ffuf() {
    local domain_file=""
    local output_dir=""
    local chunk_size="10000"
    local threads="30"
    local target_path="/.DS_Store"
    local parallel_jobs="5"
    local wordlist=""
    local use_dashboard="true"
    local refresh_rate="2"

    # Domain file selection
    domain_file=$($DIALOG_CMD --title "Domain File" --inputbox "Enter path to your domain file (270M+ domains supported):" 8 60 "$HOME/security_policy/all-zone_full.csv" 3>&1 1>&2 2>&3)

    if [[ -z "$domain_file" ]]; then
        return 1
    fi

    # Output directory
    output_dir=$($DIALOG_CMD --title "Output Directory" --inputbox "Enter output directory path:" 8 60 "./ffuf_results" 3>&1 1>&2 2>&3)

    if [[ -z "$output_dir" ]]; then
        return 1
    fi

    # Chunk size
    chunk_size=$($DIALOG_CMD --title "Chunk Size" --inputbox "Domains per chunk (1000-50000):" 8 50 "10000" 3>&1 1>&2 2>&3)

    # Threads
    threads=$($DIALOG_CMD --title "Threads" --inputbox "ffuf threads per job (10-100):" 8 50 "30" 3>&1 1>&2 2>&3)

    # Target path selection
    local path_choice=$($DIALOG_CMD --title "Target Path" --menu "Select fuzzing target:" 15 60 4         "1" ".DS_Store files (default)"         "2" "Admin panels (/admin)"         "3" "API endpoints (/api/v1/)"         "4" "Custom path" 3>&1 1>&2 2>&3)

    case $path_choice in
        1) target_path="/.DS_Store" ;;
        2) target_path="/admin" ;;
        3) target_path="/api/v1/" ;;
        4) target_path=$($DIALOG_CMD --title "Custom Path" --inputbox "Enter custom target path:" 8 50 "/" 3>&1 1>&2 2>&3) ;;
    esac

    # Wordlist (optional)
    if $DIALOG_CMD --title "Wordlist" --yesno "Do you want to use a custom wordlist for fuzzing?" 8 50; then
        wordlist=$($DIALOG_CMD --title "Wordlist Path" --inputbox "Enter path to wordlist:" 8 60 "/usr/share/wordlists/dirb/common.txt" 3>&1 1>&2 2>&3)
    fi

    # Parallel jobs
    parallel_jobs=$($DIALOG_CMD --title "Parallel Jobs" --inputbox "Maximum parallel jobs (1-20):" 8 50 "5" 3>&1 1>&2 2>&3)

    # Dashboard settings
    if command -v tmux &> /dev/null; then
        if $DIALOG_CMD --title "Dashboard" --yesno "Enable tmux dashboard for real-time monitoring?" 8 50; then
            use_dashboard="true"
            refresh_rate=$($DIALOG_CMD --title "Refresh Rate" --inputbox "Dashboard refresh rate (seconds):" 8 50 "2" 3>&1 1>&2 2>&3)
        else
            use_dashboard="false"
        fi
    else
        use_dashboard="false"
    fi

    # Save configuration
    cat > "$CONFIG_FILE" << EOF
# FFUF Automation Configuration
# Generated: $(date)

DOMAIN_FILE="$domain_file"
OUTPUT_DIR="$output_dir"
CHUNK_SIZE="$chunk_size"
THREADS="$threads"
TARGET_PATH="$target_path"
WORDLIST="$wordlist"
PARALLEL_JOBS="$parallel_jobs"
USE_DASHBOARD="$use_dashboard"
REFRESH_RATE="$refresh_rate"
EOF

    $DIALOG_CMD --title "Configuration Saved" --msgbox "Configuration saved to:\n$CONFIG_FILE\n\nSettings:\n• Domain file: $domain_file\n• Output: $output_dir\n• Chunk size: $chunk_size\n• Threads: $threads\n• Target: $target_path\n• Parallel jobs: $parallel_jobs\n• Dashboard: $use_dashboard" 16 70

    return 0
}

# Create sample data
create_sample_data() {
    local choice=$($DIALOG_CMD --title "Sample Data" --menu "Select sample data size:" 12 50 3         "1" "Small (100 domains)"         "2" "Medium (10,000 domains)"         "3" "Custom size" 3>&1 1>&2 2>&3)

    local sample_size=100
    local filename="sample_domains_small.txt"

    case $choice in
        1) 
            sample_size=100
            filename="sample_domains_small.txt"
            ;;
        2) 
            sample_size=10000
            filename="sample_domains_medium.txt"
            ;;
        3) 
            sample_size=$($DIALOG_CMD --title "Custom Size" --inputbox "Enter number of domains:" 8 50 "1000" 3>&1 1>&2 2>&3)
            filename="sample_domains_custom.txt"
            ;;
    esac

    if [[ -z "$sample_size" ]] || [[ $sample_size -lt 1 ]]; then
        $DIALOG_CMD --title "Error" --msgbox "Invalid sample size specified." 8 40
        return 1
    fi

    # Create progress bar for sample generation
    {
        echo "10"
        echo "# Creating base domain list..."

        # Create base domains
        cat > "/tmp/base_domains.txt" << 'EOF'
example.com
google.com
github.com
stackoverflow.com
reddit.com
twitter.com
facebook.com
linkedin.com
youtube.com
amazon.com
microsoft.com
apple.com
netflix.com
spotify.com
instagram.com
whatsapp.com
telegram.org
discord.com
slack.com
zoom.us
dropbox.com
wordpress.com
medium.com
dev.to
hackernews.org
producthunt.com
angellist.com
crunchbase.com
techcrunch.com
wired.com
EOF

        echo "30"
        echo "# Generating domain variations..."

        local output_file="$SCRIPT_DIR/$filename"
        rm -f "$output_file"

        local generated=0
        local batch_size=100

        while [[ $generated -lt $sample_size ]]; do
            echo "$(( 30 + (generated * 60 / sample_size) ))"
            echo "# Generated $generated/$sample_size domains..."

            for i in $(seq 1 $batch_size); do
                if [[ $generated -ge $sample_size ]]; then
                    break
                fi

                # Pick random base domain and add variation
                local base_domain=$(shuf -n 1 "/tmp/base_domains.txt")
                local variation=$((generated + 1))

                # Create variations
                case $((i % 4)) in
                    0) echo "${base_domain%.*}-${variation}.${base_domain##*.}" >> "$output_file" ;;
                    1) echo "sub${variation}.${base_domain}" >> "$output_file" ;;
                    2) echo "app${variation}.${base_domain}" >> "$output_file" ;;
                    3) echo "api${variation}.${base_domain}" >> "$output_file" ;;
                esac

                ((generated++))
            done

            sleep 0.1
        done

        echo "90"
        echo "# Finalizing sample file..."

        # Ensure exact count
        head -n "$sample_size" "$output_file" > "/tmp/temp_domains.txt"
        mv "/tmp/temp_domains.txt" "$output_file"

        echo "100"
        echo "# Sample generation complete!"
        sleep 1

    } | $DIALOG_CMD --title "Generating Sample Data" --gauge "Initializing..." 8 60 0

    rm -f "/tmp/base_domains.txt"

    local actual_count=$(wc -l < "$output_file")
    $DIALOG_CMD --title "Sample Data Created" --msgbox "Sample file created successfully!\n\nFile: $output_file\nDomains: $actual_count\n\nYou can use this file for testing the automation system." 12 60

    return 0
}

# Launch automation with current configuration
launch_automation() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        $DIALOG_CMD --title "Error" --msgbox "No configuration found. Please configure settings first." 8 50
        return 1
    fi

    # Load configuration
    source "$CONFIG_FILE"

    # Validate domain file
    if [[ ! -f "$DOMAIN_FILE" ]]; then
        if $DIALOG_CMD --title "Domain File Missing" --yesno "Domain file not found: $DOMAIN_FILE\n\nWould you like to reconfigure or use a sample file?" 10 60; then
            return 1
        else
            return 1
        fi
    fi

    # Show launch confirmation
    local file_size=$(du -h "$DOMAIN_FILE" 2>/dev/null | cut -f1 || echo "Unknown")
    local domain_count=$(wc -l < "$DOMAIN_FILE" 2>/dev/null || echo "Unknown")

    if ! $DIALOG_CMD --title "Launch Confirmation" --yesno "Ready to launch FFUF automation with these settings:\n\nDomain file: $DOMAIN_FILE ($file_size)\nDomains: $domain_count\nOutput: $OUTPUT_DIR\nChunk size: $CHUNK_SIZE\nTarget: $TARGET_PATH\nThreads: $THREADS\nParallel jobs: $PARALLEL_JOBS\nDashboard: $USE_DASHBOARD\n\nThis will start processing. Continue?" 18 70; then
        return 1
    fi

    # Build command
    local cmd="$SCRIPT_DIR/ffuf_automation_advanced.sh -d '$DOMAIN_FILE' -o '$OUTPUT_DIR' -c '$CHUNK_SIZE' -t '$THREADS' -p '$TARGET_PATH' -j '$PARALLEL_JOBS'"

    if [[ -n "$WORDLIST" ]]; then
        cmd+=" -w '$WORDLIST'"
    fi

    if [[ "$USE_DASHBOARD" == "false" ]]; then
        cmd+=" --no-dashboard"
    else
        cmd+=" -r '$REFRESH_RATE'"
    fi

    # Clear screen and show launch message
    clear
    echo -e "${GREEN}🚀 Launching FFUF Automation...${NC}"
    echo -e "${BLUE}Command: $cmd${NC}"
    echo
    echo -e "${YELLOW}Note: If dashboard is enabled, you'll be attached to the tmux session.${NC}"
    echo -e "${YELLOW}Use Ctrl+B then 'd' to detach and return to terminal.${NC}"
    echo
    echo "Press Enter to continue..."
    read -r

    # Execute the command
    eval "$cmd"
}

# View previous results
view_results() {
    local results_dirs=()

    # Find result directories
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir/summary" ]]; then
            results_dirs+=("$(basename "$dir")" "$dir")
        fi
    done < <(find "$SCRIPT_DIR" -maxdepth 2 -type d -name "*results*" -print0 2>/dev/null)

    if [[ ${#results_dirs[@]} -eq 0 ]]; then
        $DIALOG_CMD --title "No Results" --msgbox "No previous results found." 8 40
        return 1
    fi

    local choice=$($DIALOG_CMD --title "Previous Results" --menu "Select results to view:" 15 60 8 "${results_dirs[@]}" 3>&1 1>&2 2>&3)

    if [[ -z "$choice" ]]; then
        return 1
    fi

    # Find the selected directory
    local selected_dir=""
    for ((i=0; i<${#results_dirs[@]}; i+=2)); do
        if [[ "${results_dirs[i]}" == "$choice" ]]; then
            selected_dir="${results_dirs[i+1]}"
            break
        fi
    done

    if [[ -z "$selected_dir" ]]; then
        $DIALOG_CMD --title "Error" --msgbox "Selected results directory not found." 8 40
        return 1
    fi

    # Show results summary
    local summary_file="$selected_dir/summary/final_report.txt"
    if [[ -f "$summary_file" ]]; then
        $DIALOG_CMD --title "Results Summary" --textbox "$summary_file" 20 80
    else
        $DIALOG_CMD --title "Results" --msgbox "Results directory: $selected_dir\n\nContents:\n$(ls -la "$selected_dir" 2>/dev/null | head -10)" 15 70
    fi
}

# Main menu
show_main_menu() {
    while true; do
        local choice=$($DIALOG_CMD --title "FFUF Automation Manager" --menu "Select an option:" 16 60 9             "1" "Check Prerequisites"             "2" "Configure Settings"             "3" "Create Sample Data"             "4" "Launch Automation"             "5" "View Previous Results"             "6" "Help & Documentation"             "7" "About"             "8" "Exit" 3>&1 1>&2 2>&3)

        case $choice in
            1) check_prerequisites ;;
            2) configure_ffuf ;;
            3) create_sample_data ;;
            4) launch_automation ;;
            5) view_results ;;
            6) show_help ;;
            7) show_about ;;
            8) exit 0 ;;
            *) exit 0 ;;
        esac
    done
}

# Show help
show_help() {
    $DIALOG_CMD --title "Help & Documentation" --msgbox "FFUF Automation Help\n\n1. Prerequisites: Checks for required tools\n2. Configure: Set up domain files, output paths, etc.\n3. Sample Data: Generate test domain files\n4. Launch: Start the automation with current config\n5. Results: View previous scan results\n\nFor detailed documentation, see README.md\n\nTroubleshooting:\n• Ensure ffuf is in PATH\n• Check file permissions\n• Verify domain file format\n• Monitor system resources during scans" 18 70
}

# Show about
show_about() {
    $DIALOG_CMD --title "About" --msgbox "Advanced FFUF Automation Suite v3.0\n\nA professional-grade tool for massive scale domain processing with ffuf.\n\nFeatures:\n• Intelligent chunking for 270M+ domains\n• Real-time tmux dashboard\n• Parallel processing\n• JSON prettification\n• Comprehensive logging\n• Interactive setup\n\nDeveloped for security professionals and researchers.\n\nGitHub: Advanced-FFUF-Automation" 16 60
}

# Main execution
main() {
    detect_dialog_cmd
    show_welcome
    show_main_menu
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
