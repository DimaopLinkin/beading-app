---
task: macos-library-validation
type: internal
---

## Для разработки

- Release-сборка macOS падала при запуске (`dyld: Library not loaded: CSQLite.framework ... different Team IDs`): hardened runtime не загружал встроенные нативные фреймворки, подписанные другой идентичностью, чем приложение. В `macos/Runner/Release.entitlements` добавлен `com.apple.security.cs.disable-library-validation` (решение Дмитрия: приложение ставится только для себя). Для нотаризации Developer ID это допустимо.
