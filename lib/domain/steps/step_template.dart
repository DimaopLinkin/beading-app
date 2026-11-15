import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:equatable/equatable.dart';

/// Картинка встроенного шаблона: PNG в памяти.
final class StepTemplateImage extends Equatable {
  const StepTemplateImage({required this.id, required this.png, required this.width, required this.height});

  final String id;
  final Uint8List png;
  final int width;
  final int height;

  @override
  List<Object?> get props => <Object?>[id, png, width, height];
}

/// Встроенный шаблон инструкции (RAW, ёлочка и т. д.). Проект получает **копию**: шаблоны обновляются
/// вместе с приложением, а её проект — нет.
final class StepTemplate extends Equatable {
  const StepTemplate({
    required this.id,
    required this.title,
    this.description = '',
    this.palette = const <PatternColor>[],
    required this.sections,
    this.images = const <StepTemplateImage>[],
  });

  final String id;
  final String title;
  final String description;
  final List<PatternColor> palette;
  final List<StepSection> sections;
  final List<StepTemplateImage> images;

  @override
  List<Object?> get props => <Object?>[id, title, description, palette, sections, images];
}

/// Откуда берутся встроенные шаблоны. Реализация на ассетах — T33e; список техник утверждает владелец продукта.
abstract interface class StepTemplateSource {
  Future<Result<List<StepTemplate>>> all();

  /// [NotFoundFailure](../../core/failure.dart), если шаблона нет.
  Future<Result<StepTemplate>> get(String id);
}

/// Пока нет ассетов (T33e): шаблонов нет.
final class EmptyStepTemplateSource implements StepTemplateSource {
  const EmptyStepTemplateSource();

  @override
  Future<Result<List<StepTemplate>>> all() async => const Success<List<StepTemplate>>(<StepTemplate>[]);

  @override
  Future<Result<StepTemplate>> get(String id) async => Err<StepTemplate>(NotFoundFailure('Нет шаблона $id'));
}
