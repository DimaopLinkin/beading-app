---
task: macos-arm64
type: internal
---

## Для разработки

- Исправлена сборка Release/Profile для macOS на Xcode 27.1: проверка `lipo -verify_arch` во Flutter 3.41 падала на универсальном `FlutterMacOS.framework`. В `macos/Runner.xcodeproj` для Release и Profile заданы `ARCHS = arm64` и `ONLY_ACTIVE_ARCH = YES`. Intel-сборка macOS не поддерживается (минимум macOS 26).
