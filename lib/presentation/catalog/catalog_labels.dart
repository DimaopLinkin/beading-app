import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/color_similarity.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';

extension CatalogMaterialLabel on CatalogMaterial {
  String title(AppLocalizations l10n) => switch (this) {
    CatalogMaterial.bead => l10n.catalogTitleBead,
    CatalogMaterial.floss => l10n.catalogTitleFloss,
  };
}

extension SimilarityLevelLabel on SimilarityLevel {
  String label(AppLocalizations l10n) => switch (this) {
    SimilarityLevel.nearlyIdentical => l10n.similarityNearlyIdentical,
    SimilarityLevel.veryClose => l10n.similarityVeryClose,
    SimilarityLevel.close => l10n.similarityClose,
    SimilarityLevel.noticeable => l10n.similarityNoticeable,
  };
}

extension CatalogColorLabel on CatalogColor {
  /// «Miyuki Delica 11/0»; у ниток без размера — «DMC Мулине».
  String origin(AppLocalizations l10n) => l10n.catalogSeriesAndSize(brand, series, sizeCode ?? '').trim();
}
