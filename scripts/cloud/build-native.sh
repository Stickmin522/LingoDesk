#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$ANDROID_HOME/ndk/26.1.10909125/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"
export CC_aarch64_linux_android="$CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER"
export AR_aarch64_linux_android="$ANDROID_HOME/ndk/26.1.10909125/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
cd "$LINGODESK_REPO_DIR"
cargo build --manifest-path rust/Cargo.toml --locked --release --target aarch64-linux-android -j 4
mkdir -p app/android/app/src/main/jniLibs/arm64-v8a
cp rust/target/aarch64-linux-android/release/liblecsync_core.so app/android/app/src/main/jniLibs/arm64-v8a/
