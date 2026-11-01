import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';

import '../domain/models/celestial_object.dart';

abstract interface class CatalogAssetSource {
  Future<CelestialCatalogBundle> load();
}

final class BundledOpenNgcCatalogSource implements CatalogAssetSource {
  const BundledOpenNgcCatalogSource({
    this.assetPath = 'assets/catalog/openngc_20260501.json',
  });

  final String assetPath;

  @override
  Future<CelestialCatalogBundle> load() async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);

      final decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Catalog root must be a JSON object.');
      }

      return CelestialCatalogBundle.fromJson(decoded);
    } catch (_) {
      AppLogger.error('catalog_asset_load_failed');

      throw const StorageFailure(
        'Unable to load the bundled celestial catalog. '
        'Verify that the OpenNGC asset is included '
        'in the application build.',
      );
    }
  }
}
