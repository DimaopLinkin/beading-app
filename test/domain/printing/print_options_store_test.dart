import 'package:beading/domain/printing/print_options.dart';
import 'package:beading/domain/printing/print_options_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_settings_repository.dart';

void main() {
  test('места на стойке хранятся в каждой вышивке отдельно, формат листа общий (T83)', () async {
    final PrintOptionsStore store = PrintOptionsStore(FakeSettingsRepository());

    expect(await store.load(projectId: 'a'), const PrintOptions());

    await store.save(const PrintOptions(paper: PrintPaper.a3, slotsPerRack: 80), projectId: 'a');
    await store.save(const PrintOptions(slotsPerRack: 100), projectId: 'b');

    expect(await store.load(projectId: 'a'), const PrintOptions(slotsPerRack: 80), reason: 'свои места вышивки A');
    expect(await store.load(projectId: 'b'), const PrintOptions(slotsPerRack: 100));
    expect((await store.load(projectId: 'a')).paper, PrintPaper.a4, reason: 'формат — последний выбранный');
    expect(await store.load(projectId: 'c'), const PrintOptions(slotsPerRack: 100), reason: 'новая вышивка — общие');
    expect(await store.load(), const PrintOptions(slotsPerRack: 100));
  });
}
