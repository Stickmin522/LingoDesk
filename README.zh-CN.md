# 听译台

[English](README.md) · **简体中文** · [日本語](README.ja.md)

听译台可以把说话声和手机播放的音频实时转换为双语字幕，并整理成纪要。适合课堂、网课、会议和日常对话，也可以用悬浮字幕边看其他应用边听译。

<p align="center"><img src="docs/images/lingodesk-logo-rounded.png" width="240" height="240" alt="听译台 APP 图标" /></p>

## 运行截图

<p><img src="docs/images/captions.png" width="240" alt="双语字幕" /> <img src="docs/images/overlay.png" width="240" alt="悬浮字幕" /></p>

[下载安装包](https://github.com/Stickmin522/LingoDesk/releases/latest)

## 功能

- 支持麦克风、系统音频，以及两者同时录制。
- 支持日中、英中双向翻译，同时显示原文和译文。
- 双语字幕和实时纪要通过按钮切换。
- 查看历史、切换页面或使用其他应用时，录音和翻译在后台继续；在 APP 内点击停止才结束录音。
- 悬浮字幕可拖动、缩放，顶部操作栏自动隐藏；关闭悬浮窗不停止录音。
- 记住悬浮窗的开启状态、位置和大小。
- 支持历史录音回放，以及 WAV、TXT、SRT、JSON 导出。
- 适配手机、平板、横屏、分屏和折叠屏，支持浅色与深色主题。

## 使用

支持 Android 10 及以上的 ARM64 设备，应用界面为简体中文。

1. 安装 APK，按下方说明配置服务。
2. 选择翻译语言和音源，按提示授权，然后开始录音。
3. 开启悬浮字幕并允许显示在其他应用上层，返回桌面后即可查看字幕。
4. 回到 APP 内停止并保存，在历史记录中回放或导出。

## LecSync

语音识别、实时翻译和纪要使用 LecSync API，需要联网。请在 [LecSync 控制台](https://www.lecsync.com/dashboard/api) 创建自己的 API Key，再填入 APP 设置；用量和费用归该 Key 所属账号。APP 直接连接 API，不依赖另行搭建的翻译网站。录音和历史保存在本机，不与网站账号同步。服务详情见 [API 说明](https://www.lecsync.com/developers)。

## 从源码构建

见[构建说明](docs/BUILD.md)。

## 相关词条

Android、Flutter、Rust、Kotlin、实时翻译、同声听译、语音转文字、双语字幕、悬浮字幕、后台录音、音频录制、系统音频、AudioPlaybackCapture、MediaProjection、ARM64、Android 17、日语中文翻译、英语中文翻译、会议纪要。
