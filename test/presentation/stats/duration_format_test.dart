import 'package:beading/presentation/l10n/app_localizations_ru.dart';
import 'package:beading/presentation/stats/duration_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizationsRu l10n = AppLocalizationsRu();
  String f(Duration d) => formatWorkTime(l10n, d);

  test('минуты, часы, часы с минутами', () {
    expect(f(Duration.zero), '0 мин');
    expect(f(const Duration(minutes: 45)), '45 мин');
    expect(f(const Duration(minutes: 65)), '1 ч 05 мин');
    expect(f(const Duration(hours: 18, minutes: 40)), '18 ч 40 мин');
    expect(f(const Duration(hours: 2)), '2 ч');
  });

  test('от 100 ч минуты не пишем, от 240 ч — дни', () {
    expect(f(const Duration(hours: 126, minutes: 30)), '126 ч');
    expect(f(const Duration(hours: 239, minutes: 59)), '239 ч');
    expect(f(const Duration(hours: 244)), '10 д 4 ч');
    expect(f(const Duration(hours: 960)), '40 д 0 ч');
  });
}
