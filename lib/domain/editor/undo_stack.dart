import 'package:beading/domain/editor/editor_snapshot.dart';
import 'package:beading/domain/grid/grid.dart';

/// История правок схемы: undo/redo поверх неизменяемых снимков [Grid] или [EditorSnapshot] (сетка и слои вышивки).
///
/// Лимит — [limit] шагов; кроме того, суммарный размер снимков ограничен [maxTotalCells], чтобы история огромной
/// схемы не съела память (старые шаги отбрасываются первыми, текущее состояние остаётся всегда).
/// Мазок кисти группируется: [beginGroup] … [endGroup] — один шаг undo.
class UndoStack<T extends Object> {
  UndoStack(T initial, {this.limit = 100, this.maxTotalCells = 16 * 1024 * 1024})
    : assert(limit >= 1, 'limit должен быть не меньше 1'),
      _current = initial;

  final int limit;
  final int maxTotalCells;

  T _current;
  final List<T> _undo = <T>[];
  final List<T> _redo = <T>[];
  bool _inGroup = false;
  bool _groupRecorded = false;

  T get current => _current;

  bool get canUndo => _undo.isNotEmpty;

  bool get canRedo => _redo.isNotEmpty;

  /// Сколько шагов можно отменить.
  int get undoDepth => _undo.length;

  bool get isGrouping => _inGroup;

  /// Принимает новое состояние. Равное текущему игнорируется (и не стирает redo).
  void apply(T next) {
    if (next == _current) return;
    if (!_inGroup || !_groupRecorded) {
      _undo.add(_current);
      _redo.clear();
      _groupRecorded = true;
      _trim();
    }
    _current = next;
  }

  /// Начало мазка: все [apply] до [endGroup] станут одним шагом.
  void beginGroup() {
    _inGroup = true;
    _groupRecorded = false;
  }

  /// Конец мазка.
  void endGroup() {
    _inGroup = false;
    _groupRecorded = false;
  }

  /// Отменяет шаг. Возвращает новое состояние или `null`, если отменять нечего.
  T? undo() {
    endGroup();
    if (_undo.isEmpty) return null;
    _redo.add(_current);
    return _current = _undo.removeLast();
  }

  /// Повторяет отменённый шаг. Возвращает новое состояние или `null`.
  T? redo() {
    endGroup();
    if (_redo.isEmpty) return null;
    _undo.add(_current);
    return _current = _redo.removeLast();
  }

  /// Забывает историю, оставляя текущее состояние (после сохранения файла и т. п.).
  void clear() {
    endGroup();
    _undo.clear();
    _redo.clear();
  }

  void _trim() {
    while (_undo.length > limit) {
      _undo.removeAt(0);
    }
    int total = _undo.fold<int>(0, (sum, g) => sum + _weight(g));
    while (total > maxTotalCells && _undo.isNotEmpty) {
      total -= _weight(_undo.removeAt(0));
    }
  }

  /// Вес снимка: число ячеек сетки (слои вышивки разрежены и в счёт не идут).
  static int _weight(Object state) => switch (state) {
    Grid() => state.cells.length,
    EditorSnapshot() => state.grid.cells.length,
    _ => 1,
  };
}
