#!/bin/bash

# Script to generate self-signed SSL certificates for local development
# This creates certificates for localhost that will work with nginx

SSL_DIR="$(dirname "$0")/ssl"
DAYS=365

echo "Generating self-signed SSL certificates for local development..."

# Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Generate private key
openssl genrsa -out "$SSL_DIR/key.pem" 2048

# Generate certificate signing request
openssl req -new -key "$SSL_DIR/key.pem" -out "$SSL_DIR/csr.pem" -subj "/C=FR/ST=France/L=Paris/O=Aides Simplifiees Dev/OU=Development/CN=localhost"

# Generate self-signed certificate
openssl x509 -req -in "$SSL_DIR/csr.pem" -signkey "$SSL_DIR/key.pem" -out "$SSL_DIR/cert.pem" -days $DAYS -extensions v3_req -extfile <(
cat <<EOF
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
)

# Clean up CSR file
rm "$SSL_DIR/csr.pem"

# Set appropriate permissions
chmod 600 "$SSL_DIR/key.pem"
chmod 644 "$SSL_DIR/cert.pem"

echo "SSL certificates generated successfully!"
echo "Certificate: $SSL_DIR/cert.pem"
echo "Private key: $SSL_DIR/key.pem"
echo ""
echo "To trust the certificate in your browser:"
echo "1. Open the certificate file: $SSL_DIR/cert.pem"
echo "2. Add it to your system's trusted certificates"
echo "3. Or accept the security warning when accessing https://localhost"
