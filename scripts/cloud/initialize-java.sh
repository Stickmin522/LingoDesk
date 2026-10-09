#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
for ca_file in /usr/local/share/ca-certificates/*.crt; do
    ca_digest=$(sha256sum "$ca_file")
    ca_alias="lingodesk-$(basename "$ca_file" .crt)-${ca_digest%% *}"
    if ! keytool -list -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit -alias "$ca_alias" >/dev/null 2>&1; then
        keytool -importcert -noprompt -trustcacerts -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit -alias "$ca_alias" -file "$ca_file"
    fi
done
python3 - <<'PY'
from pathlib import Path
from urllib.parse import urlsplit
import os
proxy = urlsplit(os.environ.get('HTTPS_PROXY', ''))
properties = Path(os.environ['GRADLE_USER_HOME'])/'gradle.properties'
properties.parent.mkdir(parents=True, exist_ok=True)
# This file is owned by onboarding. Keep proxy credentials out of it.
lines = ['org.gradle.daemon=false', 'org.gradle.workers.max=4']
if proxy.hostname:
    port = proxy.port or (443 if proxy.scheme == 'https' else 80)
    for protocol in ('http', 'https'):
        lines += [f'systemProp.{protocol}.proxyHost={proxy.hostname}', f'systemProp.{protocol}.proxyPort={port}']
    lines += ['systemProp.http.nonProxyHosts=localhost|127.*']
properties.write_text('\n'.join(lines) + '\n')
PY
