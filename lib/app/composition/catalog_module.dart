import 'package:beading/app/composition/app_routes.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';
import 'package:beading/data/catalog/catalog_seeder.dart';
import 'package:beading/data/catalog/drift_catalog_repository.dart';
import 'package:beading/data/floss_stock/drift_floss_stock_repository.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/domain/floss_stock/floss_stock_repository.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/catalog/catalog_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Каталог бисера и мулине и запас ниток «есть у меня» (ADR-0007).
final class CatalogModule {
  CatalogModule({required CoreModule core, CatalogAssetSource? assets}) : _core = core, _assets = assets;

  final CoreModule _core;
  final CatalogAssetSource? _assets;

  late final CatalogAssetSource assetSource = _assets ?? BundleCatalogAssetSource();

  late final CatalogSeeder seeder = CatalogSeeder(dao: _core.database.catalogDao, assets: assetSource);

  late final CatalogRepository repository = DriftCatalogRepository(_core.database.catalogDao);

  late final FlossStockRepository flossStock = DriftFlossStockRepository(
    dao: _core.database.flossStockDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
    ids: _core.ids,
  );

  /// Новый на каждый вызов.
  FindSimilarColors findSimilarColors() => FindSimilarColors(repository);

  /// Каталог бисера; владелец закрывает сам.
  CatalogCubit beadCatalogCubit() => CatalogCubit(
    catalog: repository,
    findSimilar: findSimilarColors(),
    settings: _core.settings,
    brandSetting: SettingKeys.defaultBeadBrand,
  );

  /// Каталог ниток мулине с запасом «есть у меня».
  CatalogCubit flossCatalogCubit() => CatalogCubit(
    catalog: repository,
    findSimilar: findSimilarColors(),
    settings: _core.settings,
    material: CatalogMaterial.floss,
    brandSetting: SettingKeys.defaultFlossBrand,
    stock: flossStock,
  );

  List<RouteBase> routes() => <RouteBase>[
    GoRoute(
      path: AppRoutes.flossCatalog,
      builder: (_, _) => BlocProvider<CatalogCubit>(
        create: (_) => flossCatalogCubit()..start(),
        child: const CatalogScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.catalog,
      builder: (_, _) => BlocProvider<CatalogCubit>(
        create: (_) => beadCatalogCubit()..start(),
        child: const CatalogScreen(),
      ),
    ),
  ];
}
