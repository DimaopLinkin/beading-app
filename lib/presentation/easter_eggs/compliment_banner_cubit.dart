import 'dart:async';

import 'package:beading/domain/easter_eggs/shown_compliment.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Текущий баннер-комплимент или `null`. Сам исчезает через [visibleFor].
class ComplimentBannerCubit extends Cubit<ShownCompliment?> {
  ComplimentBannerCubit(Stream<ShownCompliment> source) : super(null) {
    _subscription = source.listen(_show);
  }

  static const Duration visibleFor = Duration(seconds: 5);

  late final StreamSubscription<ShownCompliment> _subscription;
  Timer? _timer;

  void _show(ShownCompliment compliment) {
    _timer?.cancel();
    emit(compliment);
    _timer = Timer(visibleFor, dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (state != null) {
      emit(null);
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
