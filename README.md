# Канитель

Приложение для бисероплетения и вышивки крестиком (iOS + macOS) на Flutter 3.41. Документация — в [docs/](docs/).

```bash
git clone https://github.com/DimaopLinkin/beading-app && cd beading-app
scripts/setup.sh              # пакеты, локализации, кодогенерация drift (один раз и после смены схемы БД или .arb)
flutter run                   # или flutter run --release на подключённом iPhone / -d macos
scripts/internal/check.sh     # формат, анализатор, правила слоёв, тесты с покрытием (то же гоняет CI)
```

Сборка и установка: `flutter run --release` (iPhone) и `flutter build macos --release`, см. [docs/release.md](docs/release.md).
Остальное в `scripts/internal/` — рабочие скрипты проверок и процесса команды, руками их гонять не нужно.
