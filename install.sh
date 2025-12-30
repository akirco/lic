#!/bin/bash

# Installation script for lic CLI tool
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION="latest"
INSTALL_DIR="$HOME/.local/bin"
GITHUB_REPO="akirco/lic"
BINARY_NAME="lic"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            VERSION_ID=$VERSION_ID
        else
            OS="Linux"
            VERSION_ID="Unknown"
        fi
        ARCH=$(uname -m)
        elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
        ARCH=$(uname -m)
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="Windows"
        ARCH="x86_64"  # Most common for Windows
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    print_status "Detected OS: $OS $VERSION_ID ($ARCH)"
}

# Function to detect architecture
detect_arch() {
    case $ARCH in
        x86_64)
            ARCH="x86_64"
        ;;
        aarch64|arm64)
            ARCH="arm64"
        ;;
        i386|i686)
            ARCH="i386"
        ;;
        *)
            print_warning "Unknown architecture: $ARCH, defaulting to x86_64"
            ARCH="x86_64"
        ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command_exists curl && ! command_exists wget; then
        print_error "Neither curl nor wget is installed. Please install one of them."
        exit 1
    fi
    
    print_success "Dependencies check passed"
}

# Function to get download URL
get_download_url() {
    if [[ "$VERSION" == "latest" ]]; then
        if [[ "$OS" == "Windows" ]]; then
            echo "https://github.com/$GITHUB_REPO/releases/latest/download/lic.exe"
            elif [[ "$OS" == "macOS" ]]; then
            echo "https://github.com/$GITHUB_REPO/releases/latest/download/lic"
        else
            echo "https://github.com/$GITHUB_REPO/releases/latest/download/lic"
        fi
    else
        if [[ "$OS" == "Windows" ]]; then
            echo "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/lic.exe"
            elif [[ "$OS" == "macOS" ]]; then
            echo "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/lic"
        else
            echo "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/lic"
        fi
    fi
}

# Function to download binary
download_binary() {
    local download_url=$(get_download_url)
    local temp_file=$(mktemp)
    
    print_status "Downloading $BINARY_NAME from $download_url..."
    
    if command_exists curl; then
        if ! curl -L -o "$temp_file" "$download_url"; then
            print_error "Failed to download $BINARY_NAME"
            rm -f "$temp_file"
            exit 1
        fi
        elif command_exists wget; then
        if ! wget -O "$temp_file" "$download_url"; then
            print_error "Failed to download $BINARY_NAME"
            rm -f "$temp_file"
            exit 1
        fi
    fi
    
    print_success "Download completed"
    echo "$temp_file"
}

# Function to verify binary
verify_binary() {
    local binary_path=$1
    
    # Check if file exists and is executable
    if [[ ! -f "$binary_path" ]]; then
        print_error "Binary not found at $binary_path"
        exit 1
    fi
    
    if [[ ! -x "$binary_path" ]]; then
        print_status "Making binary executable..."
        chmod +x "$binary_path"
    fi
    
    # Try to run the binary with --version
    if ! "$binary_path" --version >/dev/null 2>&1; then
        print_warning "Binary verification failed, but installation will continue"
    else
        print_success "Binary verification passed"
    fi
}

# Function to install binary
install_binary() {
    local binary_path=$1
    local target_dir="$INSTALL_DIR"
    local target_path="$target_dir/$BINARY_NAME"
    
    # Create install directory if it doesn't exist
    if [[ ! -d "$target_dir" ]]; then
        print_status "Creating directory $target_dir..."
        mkdir -p "$target_dir"
    fi
    
    # Copy binary to install directory
    print_status "Installing $BINARY_NAME to $target_path..."
    cp "$binary_path" "$target_path"
    
    print_success "$BINARY_NAME installed successfully"
}

# Function to add to PATH
add_to_path() {
    local shell_config=""
    
    # Detect shell configuration file
    if [[ -n "$BASH_VERSION" ]]; then
        shell_config="$HOME/.bashrc"
        elif [[ -n "$ZSH_VERSION" ]]; then
        shell_config="$HOME/.zshrc"
        elif [[ -n "$FISH_VERSION" ]]; then
        shell_config="$HOME/.config/fish/config.fish"
    else
        print_warning "Unsupported shell, please add $INSTALL_DIR to PATH manually"
        return
    fi
    
    # Check if PATH already contains the install directory
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_status "Adding $INSTALL_DIR to PATH in $shell_config..."
        
        if [[ "$shell_config" == *".fish" ]]; then
            echo "set -gx PATH $INSTALL_DIR \$PATH" >> "$shell_config"
        else
            echo "" >> "$shell_config"
            echo "# Added by $BINARY_NAME installer" >> "$shell_config"
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$shell_config"
        fi
        
        print_success "PATH updated. Please restart your shell or run 'source $shell_config'"
    else
        print_status "PATH already contains $INSTALL_DIR"
    fi
}

# Function to show installation summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "Installation Summary"
    echo "=========================================="
    echo "Binary: $BINARY_NAME"
    echo "Version: $VERSION"
    echo "Install Directory: $INSTALL_DIR"
    echo "Binary Path: $INSTALL_DIR/$BINARY_NAME"
    echo ""
    echo "To use $BINARY_NAME, make sure $INSTALL_DIR is in your PATH."
    if [[ -n "${shell_config:-}" ]]; then
        echo "Run 'source $shell_config' or restart your shell to update PATH."
    fi
    echo "=========================================="
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Specify version to install (default: latest)"
    echo "  -d, --dir PATH           Installation directory (default: \$HOME/.local/bin)"
    echo "  -r, --repo REPO          GitHub repository (default: neil-lee/lic)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install latest version"
    echo "  $0 -v 0.1.0           # Install specific version"
    echo "  $0 -d /usr/local/bin  # Install to system location"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
        ;;
        -d|--dir)
            INSTALL_DIR="$2"
            shift 2
        ;;
        -r|--repo)
            GITHUB_REPO="$2"
            shift 2
        ;;
        -h|--help)
            show_help
            exit 0
        ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
        ;;
    esac
done

# Main installation process
echo "=========================================="
echo "$BINARY_NAME Installation Script"
echo "=========================================="
echo ""

# Detect system information
detect_os
detect_arch

# Check dependencies
check_dependencies

# Download binary
TEMP_FILE=$(download_binary)

# Verify binary
verify_binary "$TEMP_FILE"

# Install binary
install_binary "$TEMP_FILE"

# Clean up temporary file
rm -f "$TEMP_FILE"

# Add to PATH
add_to_path

# Show summary
show_summary

print_success "Installation completed!"