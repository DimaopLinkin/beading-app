import 'dart:async';

import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/presentation/widgets/glass/glass_policy.dart';
import 'package:flutter/widgets.dart';

/// Следит за системной настройкой «Уменьшить прозрачность» и отдаёт её стеклу через [GlassPolicy].
class ReduceTransparencyScope extends StatefulWidget {
  const ReduceTransparencyScope({required this.source, required this.child, super.key});

  final ReduceTransparencySource source;
  final Widget child;

  @override
  State<ReduceTransparencyScope> createState() => _ReduceTransparencyScopeState();
}

class _ReduceTransparencyScopeState extends State<ReduceTransparencyScope> with WidgetsBindingObserver {
  bool _reduce = false;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  @override
  void didUpdateWidget(ReduceTransparencyScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      unawaited(_subscription?.cancel());
      _reduce = false;
      _bind();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Настройку могли сменить, пока приложение было в фоне, а нативная сторона могла ответить «нет» слишком рано.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      _set(await widget.source.current());
    } on Exception {
      // Источник не ответил: остаётся прежнее значение.
    }
  }

  void _bind() {
    // Подписка раньше первого ответа: смена настройки в этот промежуток не потеряется.
    var changed = false;
    _subscription = widget.source.changes.listen((value) {
      changed = true;
      _set(value);
    });
    // Ответ на первый запрос мог устареть, если за это время пришла смена: событие новее.
    unawaited(
      widget.source
          .current()
          .then((value) {
            if (!changed) {
              _set(value);
            }
          })
          .onError<Exception>((_, _) {}),
    );
  }

  void _set(bool value) {
    if (mounted && value != _reduce) {
      setState(() => _reduce = value);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassPolicy(reduceTransparency: _reduce, child: widget.child);
}
