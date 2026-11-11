import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// В чём вводят размер: в клетках (крестиках) или в сантиметрах готовой вышивки.
enum StitchSizeUnit { cells, cm }

class NewStitchState extends Equatable {
  const NewStitchState({
    this.name = '',
    this.fabric = Fabric.standard,
    this.width = 80,
    this.height = 80,
    this.unit = StitchSizeUnit.cells,
    this.creating = false,
    this.failed = false,
    this.projectId,
  });

  /// Допустимый размер схемы в крестиках по каждой стороне.
  static const int minSide = 1;
  static const int maxSide = 500;

  final String name;
  final Fabric fabric;
  final int width;
  final int height;
  final StitchSizeUnit unit;
  final bool creating;
  final bool failed;

  /// Созданный проект: экран закрывается с ним.
  final String? projectId;

  bool get validSize => width >= minSide && width <= maxSide && height >= minSide && height <= maxSide;

  /// Размер вышивки на канве, см.
  double get widthCm => fabric.cmForCells(width < 1 ? 1 : width);

  double get heightCm => fabric.cmForCells(height < 1 ? 1 : height);

  NewStitchState copyWith({
    String? name,
    Fabric? fabric,
    int? width,
    int? height,
    StitchSizeUnit? unit,
    bool? creating,
    bool? failed,
    String? projectId,
  }) => NewStitchState(
    name: name ?? this.name,
    fabric: fabric ?? this.fabric,
    width: width ?? this.width,
    height: height ?? this.height,
    unit: unit ?? this.unit,
    creating: creating ?? this.creating,
    failed: failed ?? this.failed,
    projectId: projectId ?? this.projectId,
  );

  @override
  List<Object?> get props => <Object?>[name, fabric, width, height, unit, creating, failed, projectId];
}

/// Лист создания схемы вышивки: канва (вид, плотность, «через N», цвет) и размер в крестиках или сантиметрах.
/// Создаёт пустую схему и проект с ремеслом «вышивка».
class NewStitchCubit extends Cubit<NewStitchState> {
  NewStitchCubit({required CreateGridPattern createPattern, required this.defaultName})
    : _create = createPattern,
      super(const NewStitchState());

  final CreateGridPattern _create;

  /// Название, если ничего не введено.
  final String defaultName;

  void setName(String value) => emit(state.copyWith(name: value));

  /// Новая канва; размер в крестиках остаётся, меняется размер в сантиметрах.
  void setFabric(Fabric value) => emit(state.copyWith(fabric: value));

  void setFabricColor(Rgb color) => emit(state.copyWith(fabric: state.fabric.withColor(color)));

  void setUnit(StitchSizeUnit value) => emit(state.copyWith(unit: value));

  void setWidth(int value) => emit(state.copyWith(width: value));

  void setHeight(int value) => emit(state.copyWith(height: value));

  /// Ширина в сантиметрах: переводится в целое число крестиков по канве.
  void setWidthCm(double cm) => cm > 0 ? setWidth(state.fabric.cellsForCm(cm)) : setWidth(0);

  void setHeightCm(double cm) => cm > 0 ? setHeight(state.fabric.cellsForCm(cm)) : setHeight(0);

  Future<void> create() async {
    if (state.creating || !state.validSize) return;
    emit(state.copyWith(creating: true, failed: false));
    final String name = state.name.trim().isEmpty ? defaultName : state.name.trim();
    final Result<CreatedGridPattern> result = await _create(
      name: name,
      metrics: state.fabric,
      width: state.width,
      height: state.height,
      craft: Craft.crossStitch,
      technique: Technique.defaultFor(Craft.crossStitch),
    );
    switch (result) {
      case Success<CreatedGridPattern>(:final CreatedGridPattern value):
        emit(state.copyWith(creating: false, projectId: value.project.id));
      case Err<CreatedGridPattern>():
        emit(state.copyWith(creating: false, failed: true));
    }
  }
}
