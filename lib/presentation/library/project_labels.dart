import 'package:beading/core/failure.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

/// Русские названия перечислений предметной области и иконки ремёсел: единственное место, где они определены.
extension CraftLabel on Craft {
  String label(AppLocalizations l10n) => switch (this) {
    Craft.beading => l10n.craftBeading,
    Craft.crossStitch => l10n.craftCrossStitch,
  };

  IconData get icon => switch (this) {
    Craft.beading => CupertinoIcons.circle_grid_3x3_fill,
    Craft.crossStitch => CupertinoIcons.square_grid_2x2_fill,
  };
}

extension TechniqueLabel on Technique {
  String label(AppLocalizations l10n) => switch (this) {
    Technique.loom => l10n.techniqueLoom,
    Technique.peyote => l10n.techniquePeyote,
    Technique.brick => l10n.techniqueBrick,
    Technique.square => l10n.techniqueSquare,
    Technique.offLoom => l10n.techniqueOffLoom,
    Technique.crossStitch => l10n.techniqueCrossStitch,
    Technique.tent => l10n.techniqueTent,
  };
}

extension ProjectStatusLabel on ProjectStatus {
  String label(AppLocalizations l10n) => switch (this) {
    ProjectStatus.idea => l10n.statusIdea,
    ProjectStatus.inProgress => l10n.statusInProgress,
    ProjectStatus.done => l10n.statusDone,
  };
}

/// Текст для человека вместо технического `Failure.message`.
String failureMessage(AppLocalizations l10n, Failure failure) => switch (failure) {
  ValidationFailure() => l10n.actionFailedValidation,
  NotFoundFailure() => l10n.actionFailedNotFound,
  StorageFailure() || UnexpectedFailure() => l10n.actionFailedGeneric,
};
