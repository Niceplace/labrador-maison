#!/bin/bash

set -e

# Script to install Docker registry CA certificate for Docker daemon
# This fixes the "x509: certificate signed by unknown authority" error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CA_CERT_SOURCE="${PROJECT_ROOT}/certs/ca-chain.cert.pem"
REGISTRY_HOSTNAME="registry.thinkcenter.dev"
DOCKER_CERTS_DIR="/etc/docker/certs.d/${REGISTRY_HOSTNAME}"

echo "Installing Docker registry CA certificate..."
echo "Registry: ${REGISTRY_HOSTNAME}"
echo "CA Certificate: ${CA_CERT_SOURCE}"
echo ""

# Check if CA certificate exists
if [ ! -f "$CA_CERT_SOURCE" ]; then
    echo "ERROR: CA certificate not found at ${CA_CERT_SOURCE}"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script requires root privileges."
    echo "Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# Create Docker registry-specific certificate directory
echo "Creating directory: ${DOCKER_CERTS_DIR}"
mkdir -p "$DOCKER_CERTS_DIR"

# Copy CA certificate
echo "Copying CA certificate..."
cp "$CA_CERT_SOURCE" "${DOCKER_CERTS_DIR}/ca.crt"
chmod 644 "${DOCKER_CERTS_DIR}/ca.crt"

echo ""
echo "Certificate installed successfully!"
echo ""

# Verify the certificate
echo "Verifying certificate installation..."
if [ -f "${DOCKER_CERTS_DIR}/ca.crt" ]; then
    echo "✓ Certificate exists at ${DOCKER_CERTS_DIR}/ca.crt"
    echo ""
    openssl x509 -in "${DOCKER_CERTS_DIR}/ca.crt" -subject -issuer -noout
else
    echo "✗ Certificate installation failed"
    exit 1
fi

echo ""
echo "Restarting Docker daemon..."
systemctl restart docker

echo ""
echo "Waiting for Docker to be ready..."
sleep 2

# Check Docker status
if systemctl is-active --quiet docker; then
    echo "✓ Docker daemon is running"
else
    echo "✗ Docker daemon failed to start"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installation complete!"
echo ""
echo "You can now test with:"
echo "  docker login ${REGISTRY_HOSTNAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
