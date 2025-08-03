#!/bin/bash

# FFUF Automation Suite - Installation & Quick Start
# One-click installation and setup script

set -euo pipefail

# Colors
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
PURPLE='[0;35m'
CYAN='[0;36m'
WHITE='[1;37m'
NC='[0m'

# Installation directory
INSTALL_DIR="$HOME/.ffuf-automation"
BIN_DIR="$HOME/.local/bin"

# Create directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Display banner
show_banner() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════╗
║  ███████╗███████╗██╗   ██╗███████╗     █████╗ ██╗   ██╗████████╗ ██████╗ ║
║  ██╔════╝██╔════╝██║   ██║██╔════╝    ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗║
║  █████╗  █████╗  ██║   ██║█████╗      ███████║██║   ██║   ██║   ██║   ██║║
║  ██╔══╝  ██╔══╝  ██║   ██║██╔══╝      ██╔══██║██║   ██║   ██║   ██║   ██║║
║  ██║     ██║     ╚██████╔╝██║         ██║  ██║╚██████╔╝   ██║   ╚██████╔╝║
║  ╚═╝     ╚═╝      ╚═════╝ ╚═╝         ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ║
╠══════════════════════════════════════════════════════════════════════════╣
║                    Professional Automation Suite v3.0                   ║
║                     Massive Scale Domain Processing                      ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}🚀 Installation & Quick Start Script${NC}"
    echo
}

# Check system requirements
check_system() {
    echo -e "${BLUE}📋 Checking system requirements...${NC}"

    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${GREEN}✓${NC} Linux detected"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${GREEN}✓${NC} macOS detected"
    else
        echo -e "${RED}✗${NC} Unsupported OS: $OSTYPE"
        exit 1
    fi

    # Check bash version
    if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
        echo -e "${GREEN}✓${NC} Bash ${BASH_VERSION} (compatible)"
    else
        echo -e "${RED}✗${NC} Bash 4.0+ required (current: ${BASH_VERSION})"
        exit 1
    fi

    echo
}

# Install prerequisites
install_prerequisites() {
    echo -e "${BLUE}🔧 Installing prerequisites...${NC}"

    # Detect package manager
    local pkg_manager=""
    local install_cmd=""

    if command -v apt &> /dev/null; then
        pkg_manager="apt"
        install_cmd="sudo apt update && sudo apt install -y"
    elif command -v yum &> /dev/null; then
        pkg_manager="yum"
        install_cmd="sudo yum install -y"
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
        install_cmd="sudo dnf install -y"
    elif command -v brew &> /dev/null; then
        pkg_manager="brew"
        install_cmd="brew install"
    else
        echo -e "${YELLOW}⚠${NC} No supported package manager found. Manual installation required."
        return 1
    fi

    echo -e "${GREEN}✓${NC} Package manager: $pkg_manager"

    # Install tools
    local tools_to_install=()

    # Check ffuf
    if ! command -v ffuf &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} ffuf not found. Installing Go and ffuf..."
        if [[ "$pkg_manager" == "brew" ]]; then
            brew install go
        else
            $install_cmd golang-go
        fi
        # Install ffuf
        export GOPATH="$HOME/go"
        export PATH="$PATH:$GOPATH/bin"
        go install github.com/ffuf/ffuf@latest
        # Add to PATH permanently
        echo 'export PATH="$PATH:$HOME/go/bin"' >> ~/.bashrc
        echo -e "${GREEN}✓${NC} ffuf installed"
    else
        echo -e "${GREEN}✓${NC} ffuf already installed"
    fi

    # Check other tools
    for tool in jq tmux parallel curl wget; do
        if ! command -v "$tool" &> /dev/null; then
            tools_to_install+=("$tool")
        else
            echo -e "${GREEN}✓${NC} $tool already installed"
        fi
    done

    # Install missing tools
    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        echo -e "${BLUE}Installing: ${tools_to_install[*]}${NC}"
        if [[ "$pkg_manager" == "apt" ]]; then
            $install_cmd "${tools_to_install[@]}"
        elif [[ "$pkg_manager" == "yum" ]] || [[ "$pkg_manager" == "dnf" ]]; then
            # Handle package name differences
            local rpm_tools=()
            for tool in "${tools_to_install[@]}"; do
                case "$tool" in
                    "parallel") rpm_tools+=("parallel") ;;
                    *) rpm_tools+=("$tool") ;;
                esac
            done
            $install_cmd "${rpm_tools[@]}"
        elif [[ "$pkg_manager" == "brew" ]]; then
            # Handle brew package names
            local brew_tools=()
            for tool in "${tools_to_install[@]}"; do
                case "$tool" in
                    "parallel") brew_tools+=("parallel") ;;
                    *) brew_tools+=("$tool") ;;
                esac
            done
            $install_cmd "${brew_tools[@]}"
        fi
        echo -e "${GREEN}✓${NC} Tools installed successfully"
    fi

    echo
}

# Download and install scripts
install_scripts() {
    echo -e "${BLUE}📥 Installing FFUF automation scripts...${NC}"

    # Copy current directory scripts to install directory
    local script_files=(
        "ffuf_automation_advanced.sh"
        "ffuf_setup_gui.sh"
        "json_prettify.sh"
        "tmux.conf"
    )

    local current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    for script in "${script_files[@]}"; do
        if [[ -f "$current_dir/$script" ]]; then
            cp "$current_dir/$script" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$script" 2>/dev/null || true
            echo -e "${GREEN}✓${NC} Installed $script"
        else
            echo -e "${YELLOW}⚠${NC} $script not found in current directory"
        fi
    done

    # Create symlinks in PATH
    if [[ -f "$INSTALL_DIR/ffuf_automation_advanced.sh" ]]; then
        ln -sf "$INSTALL_DIR/ffuf_automation_advanced.sh" "$BIN_DIR/ffuf-auto"
        echo -e "${GREEN}✓${NC} Created symlink: ffuf-auto"
    fi

    if [[ -f "$INSTALL_DIR/ffuf_setup_gui.sh" ]]; then
        ln -sf "$INSTALL_DIR/ffuf_setup_gui.sh" "$BIN_DIR/ffuf-setup"
        echo -e "${GREEN}✓${NC} Created symlink: ffuf-setup"
    fi

    # Ensure BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo "export PATH="\$PATH:$BIN_DIR"" >> ~/.bashrc
        echo -e "${GREEN}✓${NC} Added $BIN_DIR to PATH"
    fi

    echo
}

# Setup tmux configuration
setup_tmux() {
    echo -e "${BLUE}🎛️ Setting up tmux configuration...${NC}"

    if [[ -f "$INSTALL_DIR/tmux.conf" ]]; then
        # Backup existing config
        if [[ -f ~/.tmux.conf ]]; then
            cp ~/.tmux.conf ~/.tmux.conf.backup.$(date +%s)
            echo -e "${YELLOW}⚠${NC} Backed up existing ~/.tmux.conf"
        fi

        # Install new config
        cp "$INSTALL_DIR/tmux.conf" ~/.tmux.conf
        echo -e "${GREEN}✓${NC} tmux configuration installed"

        # Reload tmux if running
        if tmux list-sessions &> /dev/null; then
            tmux source-file ~/.tmux.conf 2>/dev/null && echo -e "${GREEN}✓${NC} tmux configuration reloaded" || true
        fi
    fi

    echo
}

# Create sample data
create_samples() {
    echo -e "${BLUE}📊 Creating sample data...${NC}"

    local samples_dir="$INSTALL_DIR/samples"
    mkdir -p "$samples_dir"

    # Create small sample
    cat > "$samples_dir/small_domains.txt" << 'EOF'
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
hackernews.org
producthunt.com
techcrunch.com
wired.com
medium.com
EOF

    echo -e "${GREEN}✓${NC} Created small sample (20 domains)"

    # Create medium sample
    for i in {1..500}; do
        echo "sub${i}.example.com" >> "$samples_dir/medium_domains.txt"
        echo "api${i}.testsite.org" >> "$samples_dir/medium_domains.txt"
    done

    echo -e "${GREEN}✓${NC} Created medium sample (1000 domains)"

    echo
}

# Create desktop shortcuts
create_shortcuts() {
    echo -e "${BLUE}🔗 Creating shortcuts...${NC}"

    # Create desktop entry for GUI setup (Linux only)
    if [[ "$OSTYPE" == "linux-gnu"* ]] && [[ -d ~/.local/share/applications ]]; then
        cat > ~/.local/share/applications/ffuf-automation.desktop << EOF
[Desktop Entry]
Name=FFUF Automation Setup
Comment=Interactive setup for FFUF automation suite
Exec=gnome-terminal -- bash -c "$BIN_DIR/ffuf-setup; exec bash"
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Development;Network;Security;
EOF
        echo -e "${GREEN}✓${NC} Created desktop entry"
    fi

    # Create shell aliases
    local alias_content='
# FFUF Automation aliases
alias ffuf-auto="$HOME/.local/bin/ffuf-auto"
alias ffuf-setup="$HOME/.local/bin/ffuf-setup"
alias ffuf-samples="ls -la $HOME/.ffuf-automation/samples/"
alias ffuf-results="find . -name "*ffuf*results*" -type d"
'

    if ! grep -q "FFUF Automation aliases" ~/.bashrc 2>/dev/null; then
        echo "$alias_content" >> ~/.bashrc
        echo -e "${GREEN}✓${NC} Created shell aliases"
    fi

    echo
}

# Show completion message
show_completion() {
    echo -e "${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════╗
║                          🎉 INSTALLATION COMPLETE! 🎉                   ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo -e "${CYAN}📁 Installation Directory:${NC} $INSTALL_DIR"
    echo -e "${CYAN}🔗 Binary Directory:${NC} $BIN_DIR"
    echo
    echo -e "${YELLOW}📋 Quick Start Commands:${NC}"
    echo -e "  ${GREEN}ffuf-setup${NC}      - Interactive GUI setup"
    echo -e "  ${GREEN}ffuf-auto${NC}       - Command-line automation"
    echo -e "  ${GREEN}ffuf-samples${NC}    - List sample domain files"
    echo -e "  ${GREEN}ffuf-results${NC}    - Find result directories"
    echo
    echo -e "${YELLOW}📊 Sample Data:${NC}"
    echo -e "  ${BLUE}Small:${NC}  $INSTALL_DIR/samples/small_domains.txt (20 domains)"
    echo -e "  ${BLUE}Medium:${NC} $INSTALL_DIR/samples/medium_domains.txt (1000 domains)"
    echo
    echo -e "${YELLOW}🚀 Getting Started:${NC}"
    echo -e "  1. ${GREEN}source ~/.bashrc${NC} (to reload shell configuration)"
    echo -e "  2. ${GREEN}ffuf-setup${NC} (run interactive setup)"
    echo -e "  3. Configure your domain file and settings"
    echo -e "  4. Launch automation with dashboard!"
    echo
    echo -e "${YELLOW}📖 Documentation:${NC}"
    echo -e "  • README.md for detailed usage"
    echo -e "  • tmux dashboard with F1-F4 shortcuts"
    echo -e "  • Real-time monitoring and progress tracking"
    echo
    echo -e "${RED}⚠️  Important:${NC} Restart your terminal or run ${GREEN}source ~/.bashrc${NC} to use new commands"
    echo
}

# Main installation process
main() {
    show_banner

    echo -e "${CYAN}This script will install the FFUF Automation Suite with all dependencies.${NC}"
    echo -e "${CYAN}Installation directory: $INSTALL_DIR${NC}"
    echo

    read -p "Continue with installation? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi

    echo
    check_system
    install_prerequisites
    install_scripts
    setup_tmux
    create_samples
    create_shortcuts
    show_completion
}

# Run installation
main "$@"
