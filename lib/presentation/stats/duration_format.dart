import 'package:beading/presentation/l10n/app_localizations.dart';

/// Время работы для экрана: «45 мин», «1 ч 05 мин», «126 ч» (от 100 ч минуты не пишем), «10 д 4 ч» (от 240 ч).
String formatWorkTime(AppLocalizations l10n, Duration duration) {
  final int minutes = duration.inMinutes < 0 ? 0 : duration.inMinutes;
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (hours >= 240) {
    return l10n.statsDaysHours(hours ~/ 24, hours % 24);
  }
  if (hours >= 100) {
    return l10n.statsHours(hours);
  }
  if (hours == 0) {
    return l10n.statsMinutes(minutes);
  }
  if (rest == 0) {
    return l10n.statsHours(hours);
  }
  return l10n.statsHoursMinutes(hours, rest.toString().padLeft(2, '0'));
}

/// Число с неразрывным пробелом между тысячами: «15 780».
String formatCount(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '\u00A0');
