#!/usr/bin/bash

CURRENT_DIR=$(pwd)
COMMON_NAME="*.thinkcenter.dev"

KEY_PATH="/root/ca/intermediate/private/wildcard.client.key.pem"
CERT_SIGNING_REQUEST_PATH="/root/ca/intermediate/csr/wildcard.client.csr.pem"
CERT_PATH="/root/ca/intermediate/certs/wildcard.client.cert.pem"

CNF_PATH="/root/ca/intermediate/openssl.cnf"
CA_CHAIN_PATH="/root/ca/intermediate/certs/ca-chain.cert.pem"

CERT_OUT="$1/wildcard.client.pem"


cd /root/ca
# Generate key
openssl genrsa -out "$KEY_PATH" 2048
echo "Generated key in $KEY_PATH"
cp -rf "$CA_CHAIN_PATH" "$1"
echo "Copied the chain into the destination directory $1"

# Generate certificate signing request
openssl req -config "$CNF_PATH" \
	-key "$KEY_PATH" \
	-new -sha256 \
	-subj "/C=CA/ST=Quebec/L=Montreal/O=Niceplace Inc/OU=Niceplace Inc Certificate Authority/CN=${COMMON_NAME}/emailAddress=s.beaulie2@gmail.com" \
	-out "$CERT_SIGNING_REQUEST_PATH"

echo "Generated certificate signing request @ $CERT_SIGNING_REQUEST_PATH"

# Generate server certificate

openssl ca -config "$CNF_PATH" \
       	-extensions usr_cert \
       	-days 375 \
       	-notext \
	-md sha256 \
	-unique_serial \
       	-in "${CERT_SIGNING_REQUEST_PATH}" \
       	-out "$CERT_OUT"

echo "Generated client certificate @ $CERT_OUT"

# Decodes and displays the certificate in human readable format
openssl x509 -noout -text -in "$CERT_OUT"

# Verify generated certificate against certificate chain
openssl verify -CAfile "$CA_CHAIN_PATH" "$CERT_OUT"
echo "Validated certificate against CA chain"
echo "✅ ALl done ! You can use the certificate now"
