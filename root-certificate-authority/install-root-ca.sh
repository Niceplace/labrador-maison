#!/usr/bin/bash

# Script to install thinkcenter.dev root certificate authority to the OS trusted store
# This ensures all certificates issued by the Niceplace Inc CA are trusted system-wide

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_CHAIN_SOURCE="${SCRIPT_DIR}/../reverse-proxy-traefik/certs/ca-chain.cert.pem"
CERT_NAME="thinkcenter-dev-ca"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Verify source certificate exists
if [ ! -f "$CA_CHAIN_SOURCE" ]; then
    print_error "CA chain certificate not found at: $CA_CHAIN_SOURCE"
    exit 1
fi

print_info "Installing thinkcenter.dev root certificate authority..."

# Detect OS and install accordingly
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_LIKE=$ID_LIKE
else
    print_error "Cannot detect operating system"
    exit 1
fi

# Function to extract root CA from chain (last certificate in the file)
extract_root_ca() {
    local chain_file="$1"
    local output_file="$2"
    
    # Split the chain into individual certificates
    csplit -s -z -f /tmp/cert- "$chain_file" '/-----BEGIN CERTIFICATE-----/' '{*}'
    
    # Find the last (root) certificate
    local last_cert=$(ls -1 /tmp/cert-* | tail -1)
    
    if [ -z "$last_cert" ]; then
        print_error "Failed to extract root certificate"
        rm -f /tmp/cert-*
        return 1
    fi
    
    # Copy root certificate to output
    cat "$last_cert" > "$output_file"
    
    # Cleanup
    rm -f /tmp/cert-*
    
    print_info "Extracted root CA certificate"
    
    # Display certificate info
    openssl x509 -in "$output_file" -noout -subject -issuer -dates
}

install_arch_based() {
    local ca_dest="/etc/ca-certificates/trust-source/anchors/${CERT_NAME}.crt"
    
    print_info "Detected Arch-based distribution: $PRETTY_NAME"
    
    # Extract and install root CA
    extract_root_ca "$CA_CHAIN_SOURCE" "$ca_dest"
    
    print_info "Updating system trust store..."
    update-ca-trust
    
    print_info "✅ Root CA installed successfully for Arch-based system"
}

install_debian_based() {
    local ca_dest="/usr/local/share/ca-certificates/${CERT_NAME}.crt"
    
    print_info "Detected Debian-based distribution: $PRETTY_NAME"
    
    # Extract and install root CA
    extract_root_ca "$CA_CHAIN_SOURCE" "$ca_dest"
    
    print_info "Updating system trust store..."
    update-ca-certificates
    
    print_info "✅ Root CA installed successfully for Debian-based system"
}

# Install based on distribution
case "$OS" in
    manjaro|arch)
        install_arch_based
        ;;
    debian|ubuntu|mint|pop)
        install_debian_based
        ;;
    *)
        # Check ID_LIKE for derivative distributions
        case "$OS_LIKE" in
            *arch*)
                install_arch_based
                ;;
            *debian*)
                install_debian_based
                ;;
            *)
                print_error "Unsupported distribution: $OS"
                print_warn "Please manually install the CA certificate from: $CA_CHAIN_SOURCE"
                exit 1
                ;;
        esac
        ;;
esac

# Verify installation
print_info "Verifying installation..."

# Test with openssl
if openssl verify -CApath /etc/ssl/certs/ "$CA_CHAIN_SOURCE" >/dev/null 2>&1; then
    print_info "✅ Certificate verification successful"
else
    print_warn "Certificate verification test did not pass, but this may be expected"
fi

echo ""
print_info "==========================================="
print_info "Installation complete!"
print_info "The thinkcenter.dev CA is now trusted."
print_info "==========================================="
echo ""
print_info "Notes:"
echo "  • All certificates signed by this CA will be trusted"
echo "  • You may need to restart applications/services to pick up the new trust store"
echo "  • Browsers like Firefox use their own certificate store and may need separate configuration"
echo ""
