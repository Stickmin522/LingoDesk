#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'Requires Linux x86_64.' >&2; exit 1; }
for prerequisite in git curl unzip xz python3 cc make; do command -v "$prerequisite" >/dev/null; done
mkdir -p "$LINGODESK_TOOLS_DIR/downloads"

# Verify trusted publisher checksums before installing downloaded toolchains.
python3 - <<'PY'
from pathlib import Path
import hashlib, os, subprocess, tarfile, zipfile
base = Path(os.environ['LINGODESK_TOOLS_DIR'])
def download(url, name, digest, algorithm='sha256'):
    target = base/'downloads'/name
    def valid():
        if not target.exists(): return False
        with target.open('rb') as stream:
            return hashlib.file_digest(stream, algorithm).hexdigest() == digest
    if not valid():
        subprocess.run(['curl', '-fSL', '--retry', '3', url, '-o', str(target)], check=True)
    if not valid(): raise SystemExit(f'Checksum mismatch: {name}')
    return target
if not Path(os.environ['JAVA_HOME']).exists():
    archive = download('https://download.oracle.com/java/21/archive/jdk-21.0.12.1_linux-x64_bin.tar.gz', 'jdk-21.tar.gz', '12f870b21301b42292558a3f872ce543affa2b86cb6458591c78388c41ddb111')
    with tarfile.open(archive) as bundle: bundle.extractall(base/'jdk', filter='data')
if not (base/'android-sdk/cmdline-tools/23.0/bin/android').exists():
    archive = download('https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip', 'commandlinetools-linux-16111833_latest.zip', 'e025545c62a8e64c7559119566a569fb1dec5f60', 'sha1')
    staging = base/'android-sdk/cmdline-tools/23.0-extract'
    with zipfile.ZipFile(archive) as bundle: bundle.extractall(staging)
    for executable in (staging/'cmdline-tools/bin').iterdir(): executable.chmod(0o755)
    (staging/'cmdline-tools').rename(base/'android-sdk/cmdline-tools/23.0')
if not (base/'gradle-9.5.0/bin/gradle').exists():
    archive = download('https://services.gradle.org/distributions/gradle-9.5.0-bin.zip', 'gradle-9.5.0-bin.zip', '553c78f50dafcd54d65b9a444649057857469edf836431389695608536d6b746')
    with zipfile.ZipFile(archive) as bundle: bundle.extractall(base)
    (base/'gradle-9.5.0/bin/gradle').chmod(0o755)
PY
if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
    cd "$LINGODESK_TOOLS_DIR/downloads"
    curl -fsSL --retry 3 https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init -o rustup-init
    curl -fsSL --retry 3 https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init.sha256 -o rustup-init.sha256
    sha256sum -c rustup-init.sha256
    chmod +x rustup-init
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.99.0
fi
bash "$LINGODESK_REPO_DIR/scripts/cloud/initialize-java.sh"
rustup toolchain install 1.99.0 --profile minimal
rustup target add --toolchain 1.99.0 aarch64-linux-android
android --no-metrics --sdk="$ANDROID_HOME" sdk install 'platforms/android-37.0' 'build-tools/37.0.0' 'ndk/26.1.10909125' 'platform-tools'
if [[ ! -d "$FLUTTER_ROOT" ]]; then
    git clone --depth 1 --branch 3.47.6 https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
test "$(git -C "$FLUTTER_ROOT" rev-parse HEAD)" = 5fc346839b5d0eef006ed8404392afb4dfae428d
flutter --version
flutter config --no-analytics
flutter precache --android --linux
cd "$LINGODESK_REPO_DIR"
cargo fetch --manifest-path rust/Cargo.toml --locked
bash scripts/cloud/build-native.sh
bash scripts/cloud/prepare-development-signing.sh
cd app
flutter pub get --enforce-lockfile
