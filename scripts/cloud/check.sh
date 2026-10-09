#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$LINGODESK_REPO_DIR/app"
flutter analyze --no-pub
flutter test --no-pub --concurrency=2 --reporter expanded
cd "$LINGODESK_REPO_DIR"
cargo test --manifest-path rust/Cargo.toml --locked -j 4
