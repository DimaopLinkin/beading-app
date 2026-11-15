import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/printing/pattern_printer.dart';
import 'package:beading/domain/printing/print_options.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:equatable/equatable.dart';

/// Готовый PDF для печати: имя файла и содержимое.
final class PatternPdf extends Equatable {
  const PatternPdf({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  @override
  List<Object?> get props => <Object?>[fileName, bytes];
}

/// Что напечатается: размер схемы и число цветов. По нему настройки печати показывают число страниц.
final class PrintSummary extends Equatable {
  const PrintSummary({required this.columns, required this.rows, required this.colors});

  final int columns;
  final int rows;
  final int colors;

  @override
  List<Object?> get props => <Object?>[columns, rows, colors];
}

/// Собирает PDF для печати схемы проекта (листы A4, 10 крестиков = 3 см).
final class ExportPatternPdf {
  const ExportPatternPdf({
    required ProjectRepository projects,
    required GridPatternRepository patterns,
    required PatternPrinter printer,
  }) : _projects = projects,
       _patterns = patterns,
       _printer = printer;

  final ProjectRepository _projects;
  final GridPatternRepository _patterns;
  final PatternPrinter _printer;

  Future<Result<PrintSummary>> summary(String projectId) async {
    final Result<GridPattern> pattern = await _patterns.getByProject(projectId);
    return pattern.map(
      (p) => PrintSummary(columns: p.grid.width, rows: p.grid.height, colors: p.palette.length),
    );
  }

  Future<Result<PatternPdf>> call(String projectId, {PrintOptions options = const PrintOptions()}) async {
    final Result<Project> project = await _projects.get(projectId);
    if (project case Err<Project>(:final Failure failure)) return Err<PatternPdf>(failure);
    final Result<GridPattern> pattern = await _patterns.getByProject(projectId);
    if (pattern case Err<GridPattern>(:final Failure failure)) return Err<PatternPdf>(failure);
    final String name = project.valueOrNull!.name;
    final Result<Uint8List> pdf = await _printer.renderPdf(
      title: name,
      options: options,
      pattern: pattern.valueOrNull!.copyWith(palette: pattern.valueOrNull!.palette.withLegibleSymbols()),
    );
    return pdf.map((bytes) => PatternPdf(fileName: '${fileNameOf(name)}.pdf', bytes: bytes));
  }

  /// Имя файла без символов, запрещённых в путях; пустое имя заменяется на «Схема».
  static String fileNameOf(String name) {
    final String cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.isEmpty ? 'Схема' : cleaned;
  }
}
