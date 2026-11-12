---
task: fix-macos-build
type: fix
---

## Для пользователя

- Исправлена сборка Release/Profile для macOS на Xcode 27.1: Flutter не мог проверить архитектуры в универсальном FlutterMacOS.framework. Теперь релизная сборка macOS идёт только под Apple Silicon (arm64).

## Для разработки

- В `macos/Runner.xcodeproj` для конфигураций Release и Profile заданы `ARCHS = arm64` и `ONLY_ACTIVE_ARCH = YES`. Intel-сборка macOS не поддерживается (macOS 26+ минимум).
