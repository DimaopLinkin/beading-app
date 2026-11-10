import 'dart:collection';

/// Скользящая статистика времени кадров для экрана проверки стекла: сборка + растеризация, в миллисекундах.
class FrameStats {
  FrameStats({this.capacity = 600}) : assert(capacity > 0, 'capacity должен быть положительным');

  /// Сколько последних кадров помним.
  final int capacity;

  final Queue<double> _window = Queue<double>();
  int _total = 0;

  /// Сколько кадров всего увидели (не только в окне).
  int get frames => _total;

  void add({required Duration build, required Duration raster}) {
    _total++;
    _window.addLast((build + raster).inMicroseconds / 1000);
    if (_window.length > capacity) {
      _window.removeFirst();
    }
  }

  void reset() {
    _total = 0;
    _window.clear();
  }

  double get averageMs => _window.isEmpty ? 0 : _window.reduce((a, b) => a + b) / _window.length;

  double get worstMs => _window.isEmpty ? 0 : _window.reduce((a, b) => a > b ? a : b);

  double get p95Ms {
    if (_window.isEmpty) {
      return 0;
    }
    final List<double> sorted = _window.toList()..sort();
    return sorted[(sorted.length * 0.95).ceil() - 1];
  }

  /// Сколько кадров окна дольше [budgetMs] (8.33 для 120 Гц, 16.67 для 60 Гц).
  int countOver(double budgetMs) => _window.where((ms) => ms > budgetMs).length;
}
