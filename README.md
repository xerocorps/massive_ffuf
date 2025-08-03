# Professional FFUF Automation Suite

A sophisticated, enterprise-grade bash automation system for processing massive domain lists (270M+ domains) with ffuf at scale. This suite provides intelligent chunking, parallel processing, comprehensive logging, and automated JSON prettification.

## 🚀 Features

### Core Capabilities
- **Massive Scale Processing**: Handle 270M+ domain files efficiently
- **Intelligent Chunking**: Split large files into configurable chunks (default: 10k domains)
- **Parallel Processing**: Configurable parallel job execution with GNU parallel support
- **Automatic JSON Prettification**: Built-in jq integration for readable results
- **Comprehensive Logging**: Detailed logs with timestamps and color-coded output
- **Error Recovery**: Robust error handling with retry mechanisms
- **Progress Monitoring**: Real-time status tracking and progress reporting
- **Directory Organization**: Clean, structured output directory management

### Advanced Features
- **Resume Functionality**: Continue interrupted processing sessions
- **Custom Target Paths**: Flexible path fuzzing beyond .DS_Store discovery
- **Wordlist Integration**: Support for custom wordlists and fuzzing patterns  
- **Status Tracking**: Individual chunk processing status monitoring
- **Summary Reports**: Automated generation of processing summaries (TXT/JSON)
- **Resource Management**: CPU core optimization and memory usage control

## 📋 Prerequisites

### Required Tools
```bash
# ffuf installation
go install github.com/ffuf/ffuf@latest

# jq for JSON prettification
sudo apt install jq        # Ubuntu/Debian
brew install jq           # macOS

# GNU parallel (recommended)
sudo apt install parallel  # Ubuntu/Debian
brew install parallel     # macOS
```

### System Requirements
- **Minimum**: 4GB RAM, 2 CPU cores
- **Recommended**: 16GB+ RAM, 8+ CPU cores for large-scale processing
- **Storage**: Sufficient space for results (estimate 10-100MB per 10k domains)

## 🛠 Installation

1. **Download the automation suite**:
```bash
# Download all scripts
curl -O https://example.com/ffuf_automation.sh
curl -O https://example.com/json_prettify.sh  
curl -O https://example.com/setup_examples.sh
```

2. **Set executable permissions**:
```bash
chmod +x *.sh
```

3. **Run setup and verification**:
```bash
./setup_examples.sh
```

## 📖 Usage

### Basic Syntax
```bash
./ffuf_automation.sh -d DOMAIN_FILE -o OUTPUT_DIR [OPTIONS]
```

### Essential Parameters
- `-d, --domains`: Path to domain file (required)
- `-o, --output`: Output directory (required)
- `-c, --chunk-size`: Domains per chunk (default: 10000)
- `-t, --threads`: ffuf threads (default: 30)
- `-j, --jobs`: Max parallel jobs (default: 5)

### Quick Start Examples

#### 1. Basic .DS_Store Discovery
```bash
./ffuf_automation.sh -d domains.txt -o ./results
```

#### 2. Advanced Configuration  
```bash
./ffuf_automation.sh \
  -d huge_domains.csv \
  -o ./scan_results \
  -c 15000 \
  -t 50 \
  -j 8 \
  -v
```

#### 3. Custom Path Fuzzing
```bash
./ffuf_automation.sh \
  -d domains.txt \
  -o ./admin_scan \
  -p "/admin" \
  -w /usr/share/wordlists/dirb/common.txt
```

## 📁 Output Structure

The automation creates a organized directory structure:

```
output_directory/
├── chunks/                    # Split domain files
│   ├── chunk_00.txt
│   ├── chunk_01.txt
│   └── ...
├── raw_results/              # Raw ffuf JSON output  
│   ├── chunk_00.json
│   └── ...
├── prettified_results/       # Prettified JSON output
│   ├── chunk_00_pretty.json
│   └── ...
├── logs/                     # Processing logs
│   ├── ffuf_automation.log
│   ├── chunk_00.log  
│   └── ...
├── status/                   # Processing status files
│   ├── chunk_00.status
│   └── ...
└── summary/                  # Final reports
    ├── processing_summary.txt
    └── processing_summary.json
```

## 🔧 Configuration Options

### Performance Tuning

**Chunk Size Guidelines**:
- Small systems: 1,000-5,000 domains per chunk
- Medium systems: 10,000-25,000 domains per chunk  
- Large systems: 25,000-50,000 domains per chunk

**Thread Configuration**:
- Conservative: 10-30 threads
- Balanced: 30-50 threads
- Aggressive: 50-100 threads (ensure target capacity)

**Parallel Jobs**:
- Should not exceed CPU cores
- Consider network bandwidth limitations
- Monitor system resources during execution

### Target Path Options

```bash
# .DS_Store discovery (default)
-p "/.DS_Store"

# Admin panel discovery
-p "/admin"

# Custom wordlist fuzzing
-p "/FUZZ" -w /path/to/wordlist.txt

# API endpoint discovery  
-p "/api/v1/FUZZ"
```

## 📊 Monitoring and Status

### Real-time Monitoring
```bash
# View processing log
tail -f output_directory/ffuf_automation.log

# Monitor chunk status
watch 'ls -la output_directory/status/ | grep -c COMPLETED'

# Check system resources
htop
```

### Status Commands
```bash
# Count completed chunks
grep -l "COMPLETED" output_directory/status/*.status | wc -l

# Find failed chunks
grep -l "FAILED" output_directory/status/*.status

# View processing summary
cat output_directory/summary/processing_summary.txt
```

## 🛠 JSON Prettification

### Standalone JSON Prettifier
```bash
# Single file prettification
./json_prettify.sh input.json output_pretty.json

# Directory processing
./json_prettify.sh -d /path/to/json/files/

# Recursive processing with force overwrite
./json_prettify.sh -r -d ./results/ -f
```

### Integration Examples
```bash
# Chain with result filtering
jq '.results[] | select(.status == 200)' pretty.json

# Convert to CSV
jq -r '.results[] | [.url, .status, .length] | @csv' results.json > results.csv

# Extract specific fields
jq '.results[].url' pretty.json | sort -u
```

## ⚠️ Security Considerations

### Rate Limiting
- Use appropriate delays to avoid overwhelming targets
- Monitor target server responses for rate limiting
- Consider implementing exponential backoff

### Legal and Ethical Use
- **Only scan domains you own or have explicit permission to test**
- Ensure compliance with applicable laws and regulations
- Respect robots.txt and terms of service
- Be aware that aggressive scanning may trigger security alerts

### Network Considerations
- Use VPN or distributed scanning for large operations
- Implement request rotation and source IP variation
- Monitor for IP blocking or blacklisting

## 🐛 Troubleshooting

### Common Issues

**ffuf command not found**:
```bash
# Install ffuf
go install github.com/ffuf/ffuf@latest
export PATH=$PATH:$(go env GOPATH)/bin
```

**jq command not found**:
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install jq

# macOS
brew install jq
```

**Permission denied**:
```bash
chmod +x *.sh
```

**Out of memory errors**:
```bash
# Reduce chunk size and parallel jobs
./ffuf_automation.sh -d domains.txt -o results -c 5000 -j 3
```

**Network timeouts**:
```bash
# Reduce thread count
./ffuf_automation.sh -d domains.txt -o results -t 20
```

### Debug Mode
```bash
# Enable verbose logging
./ffuf_automation.sh -d domains.txt -o results -v

# Check individual chunk logs
tail -f output_directory/logs/chunk_00.log
```

## 🔄 Advanced Usage

### Integration with Other Tools

**Subdomain Discovery Chain**:
```bash
# Chain with subfinder
subfinder -d target.com -silent | ./ffuf_automation.sh -d /dev/stdin -o results

# Chain with amass
amass enum -d target.com | ./ffuf_automation.sh -d /dev/stdin -o results
```

**Result Processing**:
```bash
# Aggregate all results
find results/prettified_results/ -name "*.json" -exec jq -r '.results[]' {} \; > all_results.json

# Filter successful responses
jq '.results[] | select(.status == 200)' all_results.json > success_results.json

# Extract unique URLs
jq -r '.results[].url' all_results.json | sort -u > unique_urls.txt
```

### Batch Processing
```bash
# Process multiple domain files
for domain_file in *.txt; do
    ./ffuf_automation.sh -d "$domain_file" -o "./results_$(basename "$domain_file" .txt)"
done
```

## 📈 Performance Optimization

### System Optimization
```bash
# Increase file descriptor limits
ulimit -n 65536

# Optimize TCP settings for high-volume scanning
echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog = 65535' >> /etc/sysctl.conf
sysctl -p
```

### Memory Management
```bash
# Monitor memory usage
free -h
ps aux --sort=-%mem | head

# Clear system cache if needed
sudo sync && sudo sysctl vm.drop_caches=3
```

## 📝 Changelog

### Version 2.0
- Added comprehensive error handling and recovery
- Implemented parallel processing with GNU parallel support
- Enhanced JSON prettification with standalone utility
- Added real-time progress monitoring
- Improved directory structure organization
- Added status tracking and resume functionality

### Version 1.0
- Initial release with basic chunking and ffuf integration
- Simple parallel processing using bash background jobs
- Basic logging and error handling

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [ffuf](https://github.com/ffuf/ffuf) - Fast web fuzzer written in Go
- [jq](https://stedolan.github.io/jq/) - Command-line JSON processor
- [GNU Parallel](https://www.gnu.org/software/parallel/) - Shell tool for executing jobs in parallel
- Security research community for feedback and testing

## 📞 Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check the troubleshooting section
- Review existing issues and discussions

---

**⚠️ Disclaimer**: This tool is intended for authorized security testing and research purposes only. Users are responsible for ensuring compliance with applicable laws and obtaining proper authorization before scanning any systems.