#!/bin/bash

# FFUF Automation Setup and Example Usage Script
# This script demonstrates how to use the ffuf automation system

set -euo pipefail

# Color codes
GREEN='[0;32m'
BLUE='[0;34m'
YELLOW='[1;33m'
RED='[0;31m'
NC='[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}FFUF AUTOMATION SETUP & EXAMPLES${NC}"
echo -e "${BLUE}================================${NC}"
echo

# Function to print section headers
section_header() {
    echo -e "
${GREEN}$1${NC}"
    echo -e "${GREEN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
}

# Function to print examples
print_example() {
    echo -e "
${YELLOW}Example $1:${NC} $2"
    echo -e "${GREEN}Command:${NC}"
    echo "  $3"
    if [[ -n "${4:-}" ]]; then
        echo -e "${GREEN}Description:${NC} $4"
    fi
}

section_header "PREREQUISITES CHECK"
echo "Checking required tools..."

# Check ffuf
if command -v ffuf &> /dev/null; then
    echo "✅ ffuf is installed"
else
    echo "❌ ffuf is NOT installed"
    echo "   Install with: go install github.com/ffuf/ffuf@latest"
fi

# Check jq
if command -v jq &> /dev/null; then
    echo "✅ jq is installed"
else
    echo "❌ jq is NOT installed"
    echo "   Install with: sudo apt install jq (Ubuntu/Debian)"
    echo "                 brew install jq (macOS)"
fi

# Check parallel
if command -v parallel &> /dev/null; then
    echo "✅ GNU parallel is installed"
else
    echo "⚠️  GNU parallel is NOT installed (optional but recommended)"
    echo "   Install with: sudo apt install parallel (Ubuntu/Debian)"
    echo "                 brew install parallel (macOS)"
fi

section_header "SCRIPT PERMISSIONS SETUP"
echo "Setting executable permissions on scripts..."

# Make scripts executable
chmod +x ffuf_automation.sh 2>/dev/null && echo "✅ ffuf_automation.sh made executable" || echo "❌ Failed to make ffuf_automation.sh executable"
chmod +x json_prettify.sh 2>/dev/null && echo "✅ json_prettify.sh made executable" || echo "❌ Failed to make json_prettify.sh executable"

section_header "DIRECTORY STRUCTURE EXAMPLES"
echo "The automation creates the following directory structure:"
echo
echo "output_directory/"
echo "├── chunks/                 # Split domain files"
echo "│   ├── chunk_00.txt"
echo "│   ├── chunk_01.txt"
echo "│   └── ..."
echo "├── raw_results/           # Raw ffuf JSON output"
echo "│   ├── chunk_00.json"
echo "│   └── ..."
echo "├── prettified_results/    # Prettified JSON output"
echo "│   ├── chunk_00_pretty.json"
echo "│   └── ..."
echo "├── logs/                  # Processing logs"
echo "│   ├── ffuf_automation.log"
echo "│   ├── chunk_00.log"
echo "│   └── ..."
echo "├── status/                # Processing status tracking"
echo "│   ├── chunk_00.status"
echo "│   └── ..."
echo "└── summary/               # Final reports"
echo "    ├── processing_summary.txt"
echo "    └── processing_summary.json"

section_header "SAMPLE DOMAIN FILE CREATION"
echo "Creating sample domain files for testing..."

# Create sample domain files
mkdir -p samples

# Small sample (100 domains)
cat > samples/small_domains.txt << 'EOF'
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

# Expand the small file to create a larger sample
for i in {1..100}; do
    sed "s/\.com/-${i}.com/g; s/\.org/-${i}.org/g; s/\.us/-${i}.us/g" samples/small_domains.txt >> samples/medium_domains.txt
done

echo "✅ Created samples/small_domains.txt (30 domains)"
echo "✅ Created samples/medium_domains.txt (3000 domains)"

section_header "USAGE EXAMPLES"

print_example "1" "Basic .DS_Store Discovery"     "./ffuf_automation.sh -d samples/small_domains.txt -o ./test_results"     "Scans all domains for .DS_Store files using default settings"

print_example "2" "Advanced Configuration"     "./ffuf_automation.sh -d samples/medium_domains.txt -o ./advanced_results -c 5000 -t 50 -j 10 -v"     "Uses 5000 domains per chunk, 50 threads, max 10 parallel jobs, verbose output"

print_example "3" "Custom Path Discovery"     "./ffuf_automation.sh -d samples/small_domains.txt -o ./custom_results -p "/admin""     "Scans for /admin paths instead of .DS_Store files"

print_example "4" "Directory Fuzzing with Wordlist"     "./ffuf_automation.sh -d samples/small_domains.txt -o ./dir_results -p "/FUZZ" -w /usr/share/wordlists/dirb/common.txt"     "Uses a custom wordlist for directory fuzzing"

print_example "5" "JSON Prettification Only"     "./json_prettify.sh -d ./test_results/raw_results/ -v"     "Prettifies all JSON files in the raw_results directory"

print_example "6" "Recursive JSON Processing"     "./json_prettify.sh -r -d ./test_results/ -f"     "Recursively processes all JSON files, overwriting existing pretty files"

section_header "MONITORING AND STATUS"
echo "While the automation runs, you can monitor progress:"
echo
echo "# View processing log in real-time"
echo "tail -f output_directory/ffuf_automation.log"
echo
echo "# Check status of individual chunks"
echo "ls -la output_directory/status/"
echo
echo "# Count completed chunks"
echo "grep -l 'COMPLETED' output_directory/status/*.status | wc -l"
echo
echo "# View final summary"
echo "cat output_directory/summary/processing_summary.txt"

section_header "PERFORMANCE TUNING"
echo "Adjust these parameters based on your system:"
echo
echo "• Chunk Size (-c):"
echo "  - Smaller chunks (1K-5K): Better for systems with limited memory"
echo "  - Larger chunks (10K-50K): Better for high-performance systems"
echo
echo "• Thread Count (-t):"
echo "  - Conservative: 10-30 threads"
echo "  - Aggressive: 50-100 threads (ensure target can handle the load)"
echo
echo "• Parallel Jobs (-j):"
echo "  - Should not exceed CPU cores"
echo "  - Consider network bandwidth limitations"

section_header "TROUBLESHOOTING"
echo "Common issues and solutions:"
echo
echo "❌ 'ffuf: command not found'"
echo "   → Install ffuf: go install github.com/ffuf/ffuf@latest"
echo
echo "❌ 'jq: command not found'"
echo "   → Install jq for JSON prettification"
echo
echo "❌ Permission denied"
echo "   → Run: chmod +x *.sh"
echo
echo "❌ Out of memory"
echo "   → Reduce chunk size (-c) and parallel jobs (-j)"
echo
echo "❌ Network timeouts"
echo "   → Reduce thread count (-t) and add delays"

section_header "SECURITY CONSIDERATIONS"
echo "Important security notes:"
echo
echo "⚠️  Rate Limiting: Use appropriate delays to avoid overwhelming targets"
echo "⚠️  Permission: Only scan domains you own or have permission to test"
echo "⚠️  Legal: Ensure compliance with applicable laws and terms of service"
echo "⚠️  Monitoring: Be aware that aggressive scanning may trigger security alerts"

section_header "ADVANCED FEATURES"
echo "Additional capabilities:"
echo
echo "• Automatic retry logic for failed chunks"
echo "• Resume functionality for interrupted scans"
echo "• Custom error handling and logging"
echo "• Integration with popular wordlists"
echo "• Batch processing of multiple domain files"
echo "• Results aggregation and deduplication"

section_header "INTEGRATION EXAMPLES"
echo "Integration with other tools:"
echo
echo "# Chain with subfinder for subdomain discovery"
echo "subfinder -d target.com | ./ffuf_automation.sh -d /dev/stdin -o ./results"
echo
echo "# Process results with additional filtering"
echo "jq '.results[] | select(.status == 200)' ./results/prettified_results/*.json"
echo
echo "# Convert to CSV for analysis"
echo "jq -r '.results[] | [.url, .status, .length] | @csv' results.json > results.csv"

echo -e "
${GREEN}Setup complete! You can now run the ffuf automation system.${NC}"
echo -e "${YELLOW}Start with the basic example and adjust parameters as needed.${NC}"
