#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
bash "$LINGODESK_REPO_DIR/scripts/cloud/initialize-java.sh"
bash "$LINGODESK_REPO_DIR/scripts/cloud/prepare-development-signing.sh"
bash "$LINGODESK_REPO_DIR/scripts/cloud/build-native.sh"
cd "$LINGODESK_REPO_DIR/app"
wrapper_mode=$(stat -c %a android/gradlew)
# Flutter adds the executable bit; restore the original checkout permissions.
trap 'chmod "$wrapper_mode" "$LINGODESK_REPO_DIR/app/android/gradlew"' EXIT
flutter pub get --enforce-lockfile
flutter build apk --release --target-platform android-arm64 --no-pub
python3 - <<'PY'
from pathlib import Path
import os, re, shutil
root = Path(os.environ['LINGODESK_REPO_DIR'])
version = re.search(r'^version:\s*([^+\s]+)', (root/'app/pubspec.yaml').read_text(), re.M)[1]
(root/'outputs').mkdir(exist_ok=True)
shutil.copy2(root/'app/build/app/outputs/flutter-apk/app-release.apk', root/f'outputs/lingodesk-{version}-arm64.apk')
PY
bash "$LINGODESK_REPO_DIR/scripts/cloud/verify-apk.sh"
