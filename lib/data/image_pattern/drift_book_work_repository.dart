import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/book_work_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/image_pattern/book_work/book_work_repository.dart';
import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/book_work/pattern_zone.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:drift/drift.dart';

/// Запомненная работа по схеме в таблицах `page_work_states` и `book_work_states`.
/// Сам ставит `created_at`, `updated_at` и `device_id`.
class DriftBookWorkRepository implements BookWorkRepository {
  DriftBookWorkRepository({required BookWorkDao dao, required DeviceIdProvider deviceIds, required Clock clock})
    : _dao = dao,
      _deviceIds = deviceIds,
      _clock = clock;

  final BookWorkDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;

  @override
  Future<Result<BookWork>> load(String patternId) {
    return guardStorage<BookWork>(() async {
      final BookWorkStateRow? book = await _dao.aliveBookState(patternId);
      final List<PageWorkStateRow> rows = await _dao.alivePageStates(patternId);
      return BookWork(
        currentPageId: book?.currentPageId,
        pages: <String, PageWork>{for (final PageWorkStateRow row in rows) row.id: _toDomain(row)},
      );
    });
  }

  @override
  Future<Result<void>> savePage(PageWork work) => _withDeviceId(
    (deviceId) => guardStorage<void>(() {
      final int now = _clock.now().millisecondsSinceEpoch;
      final RulerState ruler = work.ruler;
      final PageViewport view = work.viewport;
      final PatternZone? zone = ruler.zone;
      final Uint8List? markup = work.markup.isEmpty ? null : PageMarkupCodec.encode(work.markup);
      return _dao.upsertPageState(
        PageWorkStatesCompanion.insert(
          id: work.pageId,
          rulerTop: ruler.top,
          rulerHeight: ruler.height,
          rulerStep: ruler.step,
          rulerRow: ruler.row,
          highlight: ruler.highlight.name,
          rowDirection: Value<String>(ruler.direction.name),
          zoneTop: Value<double?>(zone?.top),
          zoneBottom: Value<double?>(zone?.bottom),
          zoneLeft: Value<double?>(zone?.left),
          zoneRight: Value<double?>(zone?.right),
          rowCount: Value<int?>(ruler.rowCount),
          markup: Value<Uint8List?>(markup),
          viewScale: view.scale,
          viewDx: view.dx,
          viewDy: view.dy,
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
        ),
        update: PageWorkStatesCompanion(
          rulerTop: Value<double>(ruler.top),
          rulerHeight: Value<double>(ruler.height),
          rulerStep: Value<double>(ruler.step),
          rulerRow: Value<int>(ruler.row),
          highlight: Value<String>(ruler.highlight.name),
          rowDirection: Value<String>(ruler.direction.name),
          zoneTop: Value<double?>(zone?.top),
          zoneBottom: Value<double?>(zone?.bottom),
          zoneLeft: Value<double?>(zone?.left),
          zoneRight: Value<double?>(zone?.right),
          rowCount: Value<int?>(ruler.rowCount),
          markup: Value<Uint8List?>(markup),
          viewScale: Value<double>(view.scale),
          viewDx: Value<double>(view.dx),
          viewDy: Value<double>(view.dy),
          updatedAt: Value<int>(now),
          deviceId: Value<String>(deviceId),
        ),
      );
    }),
  );

  @override
  Future<Result<void>> saveCurrentPage({required String patternId, required String pageId}) => _withDeviceId(
    (deviceId) => guardStorage<void>(() {
      final int now = _clock.now().millisecondsSinceEpoch;
      return _dao.upsertBookState(
        BookWorkStatesCompanion.insert(
          id: patternId,
          currentPageId: pageId,
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
        ),
        update: BookWorkStatesCompanion(
          currentPageId: Value<String>(pageId),
          updatedAt: Value<int>(now),
          deviceId: Value<String>(deviceId),
        ),
      );
    }),
  );

  PageWork _toDomain(PageWorkStateRow row) => PageWork(
    pageId: row.id,
    ruler: RulerState(
      top: row.rulerTop,
      height: row.rulerHeight,
      step: row.rulerStep,
      highlight: RulerHighlight.values.asNameMap()[row.highlight] ?? RulerHighlight.yellow,
      row: row.rulerRow,
      direction: RowDirection.values.asNameMap()[row.rowDirection] ?? RowDirection.topDown,
      zone: _zoneOf(row),
      rowCount: row.rowCount,
    ),
    viewport: PageViewport(scale: row.viewScale, dx: row.viewDx, dy: row.viewDy),
    markup: row.markup == null
        ? const PageMarkup.empty()
        : (PageMarkupCodec.decode(row.markup!) ?? const PageMarkup.empty()),
  );

  /// Зона есть, только если записаны все четыре края.
  PatternZone? _zoneOf(PageWorkStateRow row) {
    final double? top = row.zoneTop;
    final double? bottom = row.zoneBottom;
    final double? left = row.zoneLeft;
    final double? right = row.zoneRight;
    if (top == null || bottom == null || left == null || right == null) {
      return null;
    }
    return PatternZone(top: top, bottom: bottom, left: left, right: right);
  }

  Future<Result<void>> _withDeviceId(Future<Result<void>> Function(String deviceId) action) async {
    final Result<String> id = await _deviceIds.deviceId();
    return switch (id) {
      Err<String>(:final failure) => Err<void>(failure),
      Success<String>(:final String value) => action(value),
    };
  }
}
