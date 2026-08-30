#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_DIR="${QUILNODE_WORKSPACE_DIR:-$(cd "$PROJECT_DIR/.." && pwd)/workspace}"
PRIVATE_DIR="${QUILNODE_RELEASE_IDENTITY_DIR:-$WORKSPACE_DIR/private/release-identity/app-signing}"
PUBLIC_CERT="$PROJECT_DIR/Resources/QuilNodeReleaseSigning.cer"
KEYCHAIN="$PRIVATE_DIR/quilnode-release-signing.keychain-db"
KEYCHAIN_PASSWORD_FILE="$PRIVATE_DIR/keychain-password"
P12_PASSWORD_FILE="$PRIVATE_DIR/recovery-p12-password"
RECOVERY_P12="$PRIVATE_DIR/recovery/QuilNodeProjectReleaseSigning.p12"
CERT_PEM="$PRIVATE_DIR/recovery/QuilNodeProjectReleaseSigning.cer.pem"
KEY_PEM="$PRIVATE_DIR/recovery/QuilNodeProjectReleaseSigning.key.pem"
CONFIG="$PRIVATE_DIR/openssl-code-signing.cnf"
IDENTITY_NAME="QuilNode Project Release Signing"

umask 077
mkdir -p "$PRIVATE_DIR/recovery" "$(dirname "$PUBLIC_CERT")"

if [[ -e "$KEYCHAIN" || -e "$PUBLIC_CERT" ]]; then
    echo "Refusing to replace an existing project signing identity." >&2
    echo "Keychain: $KEYCHAIN" >&2
    echo "Certificate: $PUBLIC_CERT" >&2
    exit 1
fi

openssl rand -base64 48 > "$KEYCHAIN_PASSWORD_FILE"
openssl rand -base64 48 > "$P12_PASSWORD_FILE"
chmod 600 "$KEYCHAIN_PASSWORD_FILE" "$P12_PASSWORD_FILE"

cat > "$CONFIG" <<'CONFIG_EOF'
[req]
distinguished_name = subject
x509_extensions = code_signing
prompt = no

[subject]
CN = QuilNode Project Release Signing
O = QuilNode Project

[code_signing]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
CONFIG_EOF

openssl req -new -newkey rsa:3072 -nodes -x509 -sha256 -days 3650 \
    -config "$CONFIG" \
    -keyout "$KEY_PEM" \
    -out "$CERT_PEM"

openssl x509 -in "$CERT_PEM" -outform der -out "$PUBLIC_CERT"
openssl pkcs12 -export \
    -inkey "$KEY_PEM" \
    -in "$CERT_PEM" \
    -name "$IDENTITY_NAME" \
    -passout "file:$P12_PASSWORD_FILE" \
    -out "$RECOVERY_P12"

security create-keychain -p "$(<"$KEYCHAIN_PASSWORD_FILE")" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$(<"$KEYCHAIN_PASSWORD_FILE")" "$KEYCHAIN"
security import "$RECOVERY_P12" \
    -k "$KEYCHAIN" \
    -P "$(<"$P12_PASSWORD_FILE")" \
    -T /usr/bin/codesign \
    -T /usr/bin/security
security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "$(<"$KEYCHAIN_PASSWORD_FILE")" \
    "$KEYCHAIN" >/dev/null

listed=()
present=false
while IFS= read -r entry; do
    entry="${entry#*\"}"
    entry="${entry%\"*}"
    [[ -n "$entry" ]] || continue
    listed+=("$entry")
    [[ "$entry" == "$KEYCHAIN" ]] && present=true
done < <(security list-keychains -d user)
if [[ "$present" == false ]]; then
    security list-keychains -d user -s "$KEYCHAIN" "${listed[@]}"
fi

chmod 644 "$PUBLIC_CERT"
chmod 600 "$RECOVERY_P12" "$CERT_PEM" "$KEY_PEM" "$CONFIG"

fingerprint="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d :)"
not_after="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
cat > "$PRIVATE_DIR/IDENTITY.txt" <<EOF
Identity: $IDENTITY_NAME
Bundle identifier: com.quilnode.app
SHA-256 certificate fingerprint: $fingerprint
Expires: $not_after
Public certificate: $PUBLIC_CERT
Dedicated keychain: $KEYCHAIN
Encrypted recovery package: $RECOVERY_P12

The certificate is intentionally self-signed and MUST NOT be installed as a
system trust root. Certificate rotation requires explicit administrator
authorization. Keep a separately stored encrypted copy of the recovery P12 and
its password before publishing the first release.
EOF
chmod 600 "$PRIVATE_DIR/IDENTITY.txt"

# The unencrypted key was needed only to construct the encrypted recovery P12
# and dedicated keychain. Remove it after both have been verified.
openssl pkcs12 -in "$RECOVERY_P12" -passin "file:$P12_PASSWORD_FILE" -noout
test_binary="$(mktemp -t quilnode-signing-proof)"
cp /usr/bin/true "$test_binary"
certificate_sha1="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)"
codesign --force --sign "$certificate_sha1" --keychain "$KEYCHAIN" --timestamp=none "$test_binary"
codesign --verify --strict "$test_binary"
rm -f "$test_binary" "$KEY_PEM"

echo "Created project release signing identity."
echo "Public certificate: $PUBLIC_CERT"
echo "Private custody directory: $PRIVATE_DIR"
echo "SHA-256 fingerprint: $fingerprint"
