# Linux cloud development

Use the existing repository checkout in the isolated cloud environment. A separate
Git worktree is unnecessary unless explicitly requested.

The scripts require Linux x86_64, Bash, Git, curl, Python 3.11 or newer, unzip,
xz, a C compiler and make. They install the versions listed in [BUILD.md](BUILD.md)
without changing application source, dependency manifests or lockfiles.

From the repository root:

```bash
bash scripts/cloud/setup.sh
source scripts/cloud/env.sh
bash scripts/cloud/check.sh
bash scripts/cloud/build-apk.sh
```

Tools and caches default to the ignored `.tools/cloud/` directory. Set
`LINGODESK_TOOLS_DIR` before setup to use another writable location. For the
prepared Codex snapshot, use `/workspace/.lingodesk-tools` to reuse its installed
dependencies. Source `scripts/cloud/env.sh` in each new shell. Live processes and
proxy endpoints do not survive a snapshot; rerun
`bash scripts/cloud/initialize-java.sh` to refresh Java trust and proxy settings.

`setup.sh` pins Flutter 3.47.6 / Dart 3.13.5, Rust 1.99.0, JDK 21.0.12.1,
Gradle 9.5.0, Android SDK 37.0, Build Tools 37.0.0 and NDK 26.1.10909125.
Downloaded toolchains are checked against publisher checksums; Flutter is pinned
to its official Git commit. TLS verification remains enabled. Android SDK tools
download their additional packages through the official package manager.

Allow `storage.googleapis.com` for Flutter downloads in addition to the usual
GitHub, Dart, Rust, Android, Gradle and Maven package hosts. Creating GitHub
Releases and uploading assets additionally needs `api.github.com` and
`uploads.github.com`. Supply authentication through the platform's existing Git
proxy or GitHub CLI configuration; do not put tokens in these scripts.

`check.sh` runs Flutter analysis, the headless Flutter tests, and locked Rust
tests. `build-apk.sh` compiles the Android ARM64 native library, builds the APK,
and runs the existing release checker. Linux executable aliases adapt that
checker's Windows command names without changing its assertions. The expected
signing fingerprint comes from the signing keystore, independently of the APK.
The script restores the original Gradle wrapper permissions after Flutter runs.

The APK appears in `outputs/lingodesk-<version>-arm64.apk`; the verification
report is `reports/cloud-release-check.json`. Both are ignored by Git.

By default the scripts generate a **local development signing key**, with the
standard development password, outside tracked files. It differs from the
published project's original key. To reuse your own signing identity, set
`LINGODESK_SIGNING_DIR` to a directory containing `release.jks` and
`key.properties` as described in [BUILD.md](BUILD.md). Never commit private keys
or signing properties.

An Android device is required to exercise microphone/system audio recording,
MediaProjection and floating captions. Headless tests and APK builds work without
a device or a LecSync key. The current cloud machine has no attached device or
`/dev/kvm`; its adb also needs writable user storage for `.android`. Do not
overwrite `HOME` to work around the cloud filesystem restrictions. Live LecSync
translation uses the key entered in the app's settings.
