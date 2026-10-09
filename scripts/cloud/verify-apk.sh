#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$ANDROID_HOME/build-tools/37.0.0"
for tool_alias in aapt2.exe zipalign.exe apksigner.bat; do
    case "$tool_alias" in
        aapt2.exe) tool_source=aapt2 ;;
        zipalign.exe) tool_source=zipalign ;;
        apksigner.bat) tool_source=apksigner ;;
    esac
    if [[ ! -e "$tool_alias" ]]; then ln -s "$tool_source" "$tool_alias"; fi
done
mkdir -p "$LINGODESK_TOOLS_DIR/compat-bin"
cp "$LINGODESK_REPO_DIR/scripts/cloud/cmd-compat.py" "$LINGODESK_TOOLS_DIR/compat-bin/cmd.exe"
chmod +x "$LINGODESK_TOOLS_DIR/compat-bin/cmd.exe"
export PATH="$LINGODESK_TOOLS_DIR/compat-bin:$PATH"
cd "$LINGODESK_REPO_DIR"
python3 - <<'PY'
from pathlib import Path
import hashlib, os, re, subprocess
root = Path(os.environ['LINGODESK_REPO_DIR'])
version = re.search(r'^version:\s*([^+\s]+)', (root/'app/pubspec.yaml').read_text(), re.M)[1]
apk = root/f'outputs/lingodesk-{version}-arm64.apk'
properties = dict(line.split('=', 1) for line in (Path(os.environ['LINGODESK_SIGNING_DIR'])/'key.properties').read_text().splitlines() if '=' in line)
os.environ['LINGODESK_VERIFY_STORE_PASSWORD'] = properties['storePassword']
certificate = subprocess.check_output(['keytool', '-exportcert', '-keystore', str(Path(os.environ['LINGODESK_SIGNING_DIR'])/'release.jks'), '-alias', 'desk', '-storepass:env', 'LINGODESK_VERIFY_STORE_PASSWORD'])
fingerprint = hashlib.sha256(certificate).hexdigest()
subprocess.run(['python3', 'tests/verify_release.py', '--certificate-sha256', fingerprint, '--report', 'reports/cloud-release-check.json'], check=True)
PY
