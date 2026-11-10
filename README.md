# Бисер

Приложение для бисероплетения (iOS + macOS) на Flutter 3.41. Документация — в [docs/](docs/).

```bash
git clone https://github.com/DimaopLinkin/beading-app && cd beading-app
scripts/setup.sh              # пакеты, локализации, кодогенерация drift (один раз и после смены схемы БД или .arb)
flutter run                   # или flutter run --release на подключённом iPhone / -d macos
scripts/internal/check.sh     # формат, анализатор, правила слоёв, тесты с покрытием (то же гоняет CI)
```

Релиз (Ad Hoc для iPhone, Developer ID для Mac): `scripts/release_ios.sh`, `scripts/release_macos.sh`, подробности в [docs/release.md](docs/release.md).
Остальное в `scripts/internal/` — рабочие скрипты проверок и процесса команды, руками их гонять не нужно.
