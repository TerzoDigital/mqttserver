#!/bin/bash 
set -e

CERTS_DIR="./certs"
DAYS=365

mkdir -p "$CERTS_DIR" 

echo "🔑 Generating CA..."
openssl genrsa -out "$CERTS_DIR/ca.key" 2048
openssl req -x509 -new -nodes -key "$CERTS_DIR/ca.key" \
    -sha256 -days $DAYS -out "$CERTS_DIR/ca.crt" \
    -subj "/CN=Mosquitto-CA"

echo "🔑 Generating server key and CSR..."
openssl genrsa -out "$CERTS_DIR/server.key" 2048
openssl req -new -key "$CERTS_DIR/server.key" -out "$CERTS_DIR/server.csr" \
    -subj "/CN=mosquitto-broker"

echo "🔏 Signing server cert with CA..."
openssl x509 -req -in "$CERTS_DIR/server.csr" \
    -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" -CAcreateserial \
    -out "$CERTS_DIR/server.crt" -days $DAYS -sha256

# Clean up CSR
rm "$CERTS_DIR/server.csr"

echo "👤 Generating client key and CSR..."
openssl genrsa -out "$CERTS_DIR/client.key" 2048
openssl req -new -key "$CERTS_DIR/client.key" -out "$CERTS_DIR/client.csr" \
    -subj "/CN=test-client"

echo "🔏 Signing client cert with CA..."
openssl x509 -req -in "$CERTS_DIR/client.csr" \
    -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" -CAserial "$CERTS_DIR/ca.srl" \
    -out "$CERTS_DIR/client.crt" -days $DAYS -sha256

# Clean up CSR
rm "$CERTS_DIR/client.csr" 

echo "✅ Certificates generated in $CERTS_DIR:" 
ls -l "$CERTS_DIR" 
