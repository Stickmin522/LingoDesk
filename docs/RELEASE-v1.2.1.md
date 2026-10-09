# LingoDesk 1.2.1

## What's changed

- Added Linux cloud setup scripts with pinned Flutter, Dart, Rust, Java and Android toolchains.
- Added repeatable ARM64 APK builds and automated checks for signing, SDK versions, architecture and 16 KB page alignment.
- Added a documented headless development workflow with locked dependency installation and writable tool caches.
- Updated the APK version and in-app version label to 1.2.1 (version code 5).

This release keeps the recording, bilingual captions, meeting notes and 60-language features from 1.2.0.

## Validation

- Flutter analysis: no issues found.
- Flutter tests: 19 passed.
- Rust tests: 16 passed.
- ARM64 release APK: signature, SDK metadata and 16 KB alignment checks passed.

## Download

Download `lingodesk-1.2.1-arm64.apk` below. Requires Android 10 or later and an ARM64 device.

The matching source is included in `lingodesk-1.2.1-source.zip`. `SHA256SUMS.txt` provides checksums for both downloads.

**Signing compatibility:** This APK uses a newly generated local build signing key. It cannot update an installation signed with the previous project's key in place. Export recordings you want to keep before reinstalling. The source includes support for reusing a private signing directory for future builds.
