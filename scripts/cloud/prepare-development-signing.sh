#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
# Local development key only. Never replaces a user's release signing key.
mkdir -p "$LINGODESK_SIGNING_DIR"
if [[ ! -f "$LINGODESK_SIGNING_DIR/release.jks" && ! -f "$LINGODESK_SIGNING_DIR/key.properties" ]]; then
    keytool -genkeypair -keystore "$LINGODESK_SIGNING_DIR/release.jks" -storepass android -keypass android -alias desk -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=LingoDesk Local Development'
    printf 'storePassword=android\nkeyPassword=android\n' > "$LINGODESK_SIGNING_DIR/key.properties"
fi
test -f "$LINGODESK_SIGNING_DIR/release.jks"
test -f "$LINGODESK_SIGNING_DIR/key.properties"
