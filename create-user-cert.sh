#!/bin/bash

# exit straight away if something fails
set -e

# --- INPUT CHECK ---
if [ "$#" -lt 1 ]; then
  echo "Usage:"
  echo ""
  echo "  $0 <certname> [expirydays]"
  echo ""
  echo "Where <certname> will be used as the filename for the certificate"
  echo "and the CN in the certificate. [expirydays] is the number of days"
  echo "before the certificate expires, which defaults to 365 if no other"
  echo "value is given."
  exit 1
fi

# set variables from input
CERT_NAME=$1
if [ "$#" -eq 2 ]; then
    DAYS=$2
else
    DAYS=365
fi
CERTS_DIR="./certs"

# check the root certificate exists
if [ ! -d "$CERTS_DIR" ] || [ ! -f "$CERTS_DIR/server.crt" ]; then
    echo "❌ Please run generate-certs.sh before trying to create individual user certificates"
    exit 2
fi

echo "🔑 Creating a user key and certificate for '$CERT_NAME' lasting $DAYS days..."

echo "👤 Generating client key and CSR..."
openssl genrsa -out "$CERTS_DIR/$CERT_NAME.key" 2048
openssl req -new -key "$CERTS_DIR/$CERT_NAME.key" -out "$CERTS_DIR/$CERT_NAME.csr" \
    -subj "/CN=$CERT_NAME"

echo "🔏 Signing client cert with CA..."
openssl x509 -req -in "$CERTS_DIR/$CERT_NAME.csr" \
    -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" -CAserial "$CERTS_DIR/ca.srl" \
    -out "$CERTS_DIR/$CERT_NAME.crt" -days $DAYS -sha256

# Clean up CSR
rm "$CERTS_DIR/$CERT_NAME.csr" 

# Correct permissions on generated files
chown 1883:1883 "$CERTS_DIR/$CERT_NAME.crt"
chown 1883:1883 "$CERTS_DIR/$CERT_NAME.key"

echo "✅ User Certificate ("$CERTS_DIR/$CERT_NAME.crt") and private key ("$CERTS_DIR/$CERT_NAME.key") generated in $CERTS_DIR:" 
ls -l $CERTS_DIR/$CERT_NAME.*
