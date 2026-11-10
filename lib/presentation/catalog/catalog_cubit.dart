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
    this.brands = const <String>[],
    this.brand,
    this.query = '',
    this.colors = const <CatalogColor>[],
    this.selection,
  });

  final CatalogStatus status;

  /// Бренды материала для вкладок.
  final List<String> brands;

  /// Выбранная вкладка; `null` — «Все».
  final String? brand;
  final String query;

  /// Результат поиска по бренду и запросу.
  final List<CatalogColor> colors;

  /// Открытый цвет с похожими; `null`, пока ничего не выбрано.
  final SimilarSelection? selection;

  CatalogState copyWith({
    CatalogStatus? status,
    List<String>? brands,
    String? Function()? brand,
    String? query,
    List<CatalogColor>? colors,
    SimilarSelection? Function()? selection,
  }) => CatalogState(
    status: status ?? this.status,
    brands: brands ?? this.brands,
    brand: brand == null ? this.brand : brand(),
    query: query ?? this.query,
    colors: colors ?? this.colors,
    selection: selection == null ? this.selection : selection(),
  );

  @override
  List<Object?> get props => <Object?>[status, brands, brand, query, colors, selection];
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

  /// Загружает бренды и первую страницу цветов.
  Future<void> start() async {
    emit(state.copyWith(status: CatalogStatus.loading));
    final Result<List<String>> brands = await _catalog.brands(material);
    if (isClosed) return;
    if (brands is Err<List<String>>) {
      emit(state.copyWith(status: CatalogStatus.failure));
      return;
    }
    final List<String> list = brands.valueOrNull ?? const <String>[];
    String? initial;
    if (_brandSetting != null) {
      final String preferred = (await _settings.read(_brandSetting)).valueOrNull ?? '';
      if (isClosed) return;
      initial = list.contains(preferred) ? preferred : null;
    }
    emit(state.copyWith(brands: list, brand: () => initial));
    await _search();
  }

  Future<void> retry() => start();

  /// Выбирает вкладку; `null` — «Все».
  Future<void> selectBrand(String? brand) {
    emit(state.copyWith(brand: () => brand));
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
      brand: state.brand,
    );
    if (isClosed || seq != _searchSeq) return;
    switch (found) {
      case Success<List<CatalogColor>>(:final List<CatalogColor> value):
        emit(state.copyWith(status: CatalogStatus.ready, colors: value));
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
    _similarSeq++;
    emit(state.copyWith(selection: () => null));
  }
}
