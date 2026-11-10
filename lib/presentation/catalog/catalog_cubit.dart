import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CatalogStatus { loading, ready, failure }

/// Вкладка каталога: серия внутри бренда («Miyuki Delica», «Miyuki Rocailles», «Toho»).
class CatalogTab extends Equatable {
  const CatalogTab({required this.brand, required this.series, required this.showSeries});

  final String brand;
  final String series;

  /// У бренда несколько серий — в названии вкладки нужна и серия.
  final bool showSeries;

  String get label => showSeries ? '$brand $series' : brand;

  @override
  List<Object?> get props => <Object?>[brand, series, showSeries];
}

/// Выбранный цвет и подобранные к нему похожие.
class SimilarSelection extends Equatable {
  const SimilarSelection({required this.source, this.matches, this.failure});

  final CatalogColor source;

  /// `null`, пока идёт поиск.
  final List<SimilarColor>? matches;
  final Failure? failure;

  @override
  List<Object?> get props => <Object?>[source, matches, failure];
}

class CatalogState extends Equatable {
  const CatalogState({
    this.status = CatalogStatus.loading,
    this.tabs = const <CatalogTab>[],
    this.tab,
    this.query = '',
    this.colors = const <CatalogColor>[],
    this.selection,
  });

  final CatalogStatus status;

  /// Вкладки материала: серии брендов.
  final List<CatalogTab> tabs;

  /// Выбранная вкладка; `null` — «Все».
  final CatalogTab? tab;
  final String query;

  /// Результат поиска по бренду и запросу.
  final List<CatalogColor> colors;

  /// Открытый цвет с похожими; `null`, пока ничего не выбрано.
  final SimilarSelection? selection;

  CatalogState copyWith({
    CatalogStatus? status,
    List<CatalogTab>? tabs,
    CatalogTab? Function()? tab,
    String? query,
    List<CatalogColor>? colors,
    SimilarSelection? Function()? selection,
  }) => CatalogState(
    status: status ?? this.status,
    tabs: tabs ?? this.tabs,
    tab: tab == null ? this.tab : tab(),
    query: query ?? this.query,
    colors: colors ?? this.colors,
    selection: selection == null ? this.selection : selection(),
  );

  @override
  List<Object?> get props => <Object?>[status, tabs, tab, query, colors, selection];
}

/// Каталог цветов: вкладки брендов, поиск по артикулу и названию, «подобрать похожий».
class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit({
    required CatalogRepository catalog,
    required FindSimilarColors findSimilar,
    required SettingsRepository settings,
    this.material = CatalogMaterial.bead,
    SettingKey<String>? brandSetting,
  }) : _catalog = catalog,
       _findSimilar = findSimilar,
       _settings = settings,
       _brandSetting = brandSetting,
       super(const CatalogState());

  final CatalogMaterial material;
  final CatalogRepository _catalog;
  final FindSimilarColors _findSimilar;
  final SettingsRepository _settings;

  /// Настройка «производитель по умолчанию»: её бренд открывается первой вкладкой; `null` — «Все».
  final SettingKey<String>? _brandSetting;

  // Номер последнего запроса: ответ старого поиска не должен затереть результат нового.
  int _searchSeq = 0;
  int _similarSeq = 0;

  // Вкладку выбрали руками: настройка «производитель по умолчанию» её уже не меняет (поздний ответ, «Повторить»).
  bool _tabTouched = false;

  /// Загружает вкладки и цвета.
  Future<void> start() async {
    emit(state.copyWith(status: CatalogStatus.loading));
    final Result<List<CatalogColor>> all = await _catalog.search(material: material);
    if (isClosed) return;
    if (all is Err<List<CatalogColor>>) {
      emit(state.copyWith(status: CatalogStatus.failure));
      return;
    }
    final List<(String, String)> pairs = <(String, String)>[];
    for (final CatalogColor color in all.valueOrNull ?? const <CatalogColor>[]) {
      final (String, String) pair = (color.brand, color.series);
      if (!pairs.contains(pair)) pairs.add(pair);
    }
    final List<CatalogTab> tabs = <CatalogTab>[
      for (final (String brand, String series) in pairs)
        CatalogTab(brand: brand, series: series, showSeries: pairs.where((p) => p.$1 == brand).length > 1),
    ];
    CatalogTab? initial = state.tab;
    if (_brandSetting != null && !_tabTouched) {
      final String preferred = (await _settings.read(_brandSetting)).valueOrNull ?? '';
      if (isClosed) return;
      if (!_tabTouched) initial = tabs.where((t) => t.brand == preferred).firstOrNull;
    }
    emit(state.copyWith(tabs: tabs, tab: () => initial));
    await _search();
  }

  Future<void> retry() => start();

  /// Выбирает вкладку; `null` — «Все».
  Future<void> selectTab(CatalogTab? tab) {
    _tabTouched = true;
    emit(state.copyWith(tab: () => tab));
    return _search();
  }

  Future<void> setQuery(String query) {
    emit(state.copyWith(query: query));
    return _search();
  }

  Future<void> _search() async {
    final int seq = ++_searchSeq;
    final Result<List<CatalogColor>> found = await _catalog.search(
      query: state.query.trim(),
      material: material,
      brand: state.tab?.brand,
    );
    if (isClosed || seq != _searchSeq) return;
    switch (found) {
      case Success<List<CatalogColor>>(:final List<CatalogColor> value):
        final CatalogTab? tab = state.tab;
        emit(
          state.copyWith(
            status: CatalogStatus.ready,
            colors: tab == null ? value : value.where((c) => c.series == tab.series).toList(growable: false),
          ),
        );
      case Err<List<CatalogColor>>():
        emit(state.copyWith(status: CatalogStatus.failure));
    }
  }

  /// Открывает цвет и подбирает к нему 5 ближайших среди всех брендов.
  Future<void> select(CatalogColor color) async {
    final int seq = ++_similarSeq;
    emit(state.copyWith(selection: () => SimilarSelection(source: color)));
    final Result<List<SimilarColor>> result = await _findSimilar(color);
    if (isClosed || seq != _similarSeq) return;
    emit(
      state.copyWith(
        selection: () => switch (result) {
          Success<List<SimilarColor>>(:final List<SimilarColor> value) => SimilarSelection(
            source: color,
            matches: value,
          ),
          Err<List<SimilarColor>>(:final Failure failure) => SimilarSelection(source: color, failure: failure),
        },
      ),
    );
  }

  void clearSelection() {
    if (isClosed) return;
    _similarSeq++;
    emit(state.copyWith(selection: () => null));
  }
}
