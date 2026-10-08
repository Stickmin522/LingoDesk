# LingoDesk

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · **한국어** · [Français](README.fr.md) · [العربية](README.ar.md) · [Español](README.es.md) · [Deutsch](README.de.md)

LingoDesk는 말소리와 Android 기기에서 재생되는 소리를 실시간 이중 언어 자막과 회의 메모로 바꿔 주는 앱입니다. 수업, 온라인 강의, 회의, 일상 대화에 사용할 수 있으며, 다른 앱을 사용하는 동안에도 플로팅 자막으로 번역을 읽을 수 있습니다.

<p align="center"><img src="docs/images/lingodesk-logo-rounded.png" width="240" height="240" alt="LingoDesk" /></p>

## 스크린샷

<p><img src="docs/images/captions.png" width="240" alt="LingoDesk" /> <img src="docs/images/overlay.png" width="240" alt="LingoDesk" /></p>

[APK 다운로드](https://github.com/Stickmin522/LingoDesk/releases/latest)

## 주요 기능

- 마이크, 기기 내부 오디오 또는 두 음원을 함께 녹음합니다.
- 지원되는 60개 언어 중 서로 다른 두 언어를 선택하면 자동으로 양방향 번역합니다.
- 이중 언어 자막과 실시간 메모를 버튼으로 전환합니다.
- 기록을 보거나 다른 앱을 사용해도 녹음과 번역이 계속됩니다. 녹음은 앱에서 중지합니다.
- 플로팅 자막은 녹음 중 앱을 벗어났을 때만 표시됩니다. 위치와 크기를 바꿀 수 있고 도구 모음은 자동으로 숨겨집니다. 창을 닫아도 녹음은 계속됩니다.
- 플로팅 창 설정, 위치, 크기를 기억합니다.
- 인터페이스 언어 60개를 선택하거나 시스템 설정을 따를 수 있습니다. 기기에서 지원하지 않는 언어는 영어로 표시하며 시스템 글꼴을 사용합니다.
- 저장한 녹음을 재생하고 WAV, TXT, SRT, JSON으로 내보낼 수 있습니다.
- 휴대전화, 태블릿, 가로 화면, 분할 화면, 폴더블 기기와 밝은 테마·어두운 테마를 지원합니다.

## 사용 방법

Android 10 이상을 실행하는 ARM64 기기가 필요합니다.

1. APK를 설치하고 아래 안내에 따라 서비스를 설정합니다.
2. 서로 다른 두 언어와 음원을 선택한 뒤 필요한 권한을 허용하고 녹음을 시작합니다.
3. 플로팅 자막과 다른 앱 위에 표시 권한을 켜면 녹음 중 홈 화면으로 나가도 자막이 표시됩니다.
4. 앱으로 돌아와 녹음을 중지하고 저장합니다. 기록에서 재생하거나 내보낼 수 있습니다.

## LecSync

음성 인식, 실시간 번역, 메모는 LecSync API를 사용하며 인터넷 연결이 필요합니다. [LecSync 콘솔](https://www.lecsync.com/dashboard/api)에서 자신의 API 키를 만든 뒤 앱 설정에 입력하세요. 사용량과 요금은 해당 키의 계정에 청구됩니다. 앱은 API에 직접 연결하므로 별도로 만든 번역 웹사이트가 없어도 사용할 수 있습니다. 녹음과 기록은 기기에 저장되며 웹사이트 계정과 동기화되지 않습니다. 자세한 내용은 [API 문서](https://www.lecsync.com/developers)를 참고하세요.

## 소스 빌드

[빌드 안내](docs/BUILD.md)를 참고하세요.

## 관련 키워드

Android, Flutter, Rust, Kotlin, 실시간 번역, 음성 인식, 이중 언어 자막, 플로팅 자막, 백그라운드 녹음, 시스템 오디오, ARM64, Android 17, 다국어 번역, 회의 메모.
