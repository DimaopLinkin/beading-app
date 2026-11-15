/// SQL триггеров, которые кладут изменённые записи в `sync_outbox` (ADR-0006, R-01).
///
/// Ключ слияния (`sync_id`) считается в самом триггере по таблице ключей из ADR-0006. Пока в `sync_applying`
/// есть строка, триггеры молчат: входящие записи не уходят обратно на сервер.
abstract final class SyncTriggers {
  static const String _muted = 'NOT EXISTS (SELECT 1 FROM sync_applying)';

  /// Ключ проекта для строки, привязанной к `grid_patterns` по [gridPatternId].
  static String _projectOfGrid(String gridPatternId) =>
      '(SELECT project_id FROM grid_patterns WHERE id = $gridPatternId)';

  static String _projectOfImagePattern(String imagePatternId) =>
      '(SELECT project_id FROM image_patterns WHERE id = $imagePatternId)';

  // Внимание: `INSERT OR REPLACE` внутри триггера переопределяет ON CONFLICT внешнего оператора (upsert репозитория
  // молча перестаёт обновлять строки), поэтому очередь пополняется через `ON CONFLICT DO NOTHING`.
  static String _trigger(String name, String table, String event, String entity, String syncId, {String when = '1'}) =>
      'CREATE TRIGGER IF NOT EXISTS $name AFTER $event ON $table WHEN $_muted AND ($when) BEGIN '
      "INSERT INTO sync_outbox (entity, sync_id) VALUES ('$entity', $syncId) ON CONFLICT DO NOTHING; END";

  /// Триггеры, существовавшие до появления запаса бисера (схема v14–v15): шаг миграции v13→v14 ещё не знает
  /// таблицу `bead_stock`.
  static List<String> get statementsBeforeBeadStock => <String>[
    for (final String sql in statements)
      if (!sql.contains(' ON bead_stock ')) sql,
  ];

  /// Все выражения для создания (и пересоздания) триггеров.
  static List<String> get statements {
    final List<String> out = <String>[];

    void both(String table, String entity, String syncId, {String updateWhen = '1'}) {
      out
        ..add(_trigger('sync_${table}_ins', table, 'INSERT', entity, syncId))
        ..add(_trigger('sync_${table}_upd', table, 'UPDATE', entity, syncId, when: updateWhen));
    }

    both('projects', 'project', 'NEW.id');
    both('work_sessions', 'work_session', 'NEW.id');
    both('floss_stock', 'floss_stock', "NEW.brand || ':' || NEW.code");
    both('bead_stock', 'bead_stock', "NEW.brand || ':' || NEW.code");
    const String notLocal = "NEW.\"key\" NOT LIKE 'local.%'";
    out
      ..add(_trigger('sync_settings_ins', 'settings', 'INSERT', 'setting', 'NEW."key"', when: notLocal))
      ..add(_trigger('sync_settings_upd', 'settings', 'UPDATE', 'setting', 'NEW."key"', when: notLocal));

    // grid_patterns: сетка и палитра — одна запись; позиция «остановилась здесь» — отдельная сущность grid_cursor.
    out
      ..add(_trigger('sync_grid_patterns_ins', 'grid_patterns', 'INSERT', 'grid_pattern', 'NEW.project_id'))
      ..add(_trigger('sync_grid_patterns_ins_cursor', 'grid_patterns', 'INSERT', 'grid_cursor', 'NEW.project_id'))
      ..add(
        _trigger(
          'sync_grid_patterns_upd',
          'grid_patterns',
          'UPDATE',
          'grid_pattern',
          'NEW.project_id',
          when:
              'OLD.geometry IS NOT NEW.geometry OR OLD.geometry_drop IS NOT NEW.geometry_drop OR OLD.width IS NOT NEW.width '
              'OR OLD.height IS NOT NEW.height OR OLD.cell_metrics IS NOT NEW.cell_metrics OR OLD.cells IS NOT NEW.cells '
              'OR OLD.cells_codec_version IS NOT NEW.cells_codec_version OR OLD.layers IS NOT NEW.layers '
              'OR OLD.layers_codec_version IS NOT NEW.layers_codec_version OR OLD.deleted_at IS NOT NEW.deleted_at',
        ),
      )
      ..add(
        _trigger(
          'sync_grid_patterns_upd_cursor',
          'grid_patterns',
          'UPDATE',
          'grid_cursor',
          'NEW.project_id',
          when:
              'OLD.current_row IS NOT NEW.current_row OR OLD.current_bead IS NOT NEW.current_bead OR OLD.deleted_at IS NOT NEW.deleted_at',
        ),
      );

    // pattern_colors входят в запись grid_pattern.
    final String colorsProject = _projectOfGrid('NEW.grid_pattern_id');
    out
      ..add(_trigger('sync_pattern_colors_ins', 'pattern_colors', 'INSERT', 'grid_pattern', colorsProject))
      ..add(_trigger('sync_pattern_colors_upd', 'pattern_colors', 'UPDATE', 'grid_pattern', colorsProject));

    both('grid_progress_rows', 'progress_row', "${_projectOfGrid('NEW.grid_pattern_id')} || ':' || NEW.row_index");
    both('grid_progress_cells', 'progress_cell', "${_projectOfGrid('NEW.grid_pattern_id')} || ':' || NEW.block_index");

    both('image_patterns', 'image_pattern', 'NEW.project_id');
    both(
      'image_pattern_pages',
      'image_pattern_page',
      "${_projectOfImagePattern('NEW.pattern_id')} || ':' || NEW.position",
    );

    const String pageKey =
        "(SELECT (SELECT project_id FROM image_patterns WHERE id = p.pattern_id) || ':' || p.position FROM image_pattern_pages p WHERE p.id = NEW.id)";
    both('page_work_states', 'page_work', pageKey);
    both('book_work_states', 'book_work', _projectOfImagePattern('NEW.id'));

    return out;
  }
}
