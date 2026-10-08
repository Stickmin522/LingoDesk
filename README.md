# LingoDesk

**English** · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

LingoDesk turns speech and audio playing on your Android device into live bilingual captions and meeting notes. Use it for lectures, online courses, meetings and conversations, with floating captions you can read while using other apps.

<p align="center"><img src="docs/images/icon.svg" width="112" alt="LingoDesk app icon" /></p>

## Screenshots

<p><img src="docs/images/captions.png" width="240" alt="Bilingual captions" /> <img src="docs/images/overlay.png" width="240" alt="Floating captions" /></p>

[Download APK](https://github.com/Stickmin522/LingoDesk/releases/latest)

## Features

- Record microphone audio, system audio, or both.
- Translate between Japanese and Chinese, or English and Chinese, with original text and translation shown together.
- Switch between bilingual captions and live notes.
- Keep recording and translating in the background while viewing history or using other apps. Stop the recording inside the app.
- Drag and resize floating captions. The toolbar hides automatically; closing the window keeps recording running.
- Remember the floating-window setting, position and size.
- Play back saved recordings and export audio, captions and notes as WAV, TXT, SRT or JSON.
- Adapt to phones, tablets, landscape, split-screen and foldable screens, with light and dark themes.

## Getting started

Requires Android 10 or later and an ARM64 device. The app interface is in Simplified Chinese.

1. Install the APK and configure the service below.
2. Select a language pair and audio source, grant the requested permissions, and start recording.
3. Enable floating captions and allow display over other apps to read captions after returning home.
4. Return to the app to stop and save. Open history to replay or export a recording.

## LecSync

Speech recognition, live translation and meeting notes use the LecSync API and require an internet connection. Create your own API key in the [LecSync console](https://www.lecsync.com/dashboard/api), then enter it in the app's settings. Usage is charged to the account associated with that key. The app connects directly to the API, so it does not depend on a separately deployed translation website. Recordings and history are saved on your device and are not synchronized with a website account. See the [API documentation](https://www.lecsync.com/developers) for service details.

## Build from source

See the [build guide](docs/BUILD.md).

## Keywords

Android, Flutter, Rust, Kotlin, live translation, speech-to-text, bilingual captions, floating subtitles, background recording, audio recording, system audio capture, AudioPlaybackCapture, MediaProjection, ARM64, Android 17, Japanese–Chinese translation, English–Chinese translation, meeting notes.
