import 'package:flutter_riverpod/misc.dart';

import 'package:astromanager/features/targets/application/celestial_catalog_controller.dart';

/// Provides an immediately available, empty catalog for
/// navigation widget tests.
///
/// The OpenNGC asset is not loaded and no SQLite database
/// is opened by the catalog provider.
Override createCatalogNavigationTestOverride() {
  return celestialCatalogProvider.overrideWithBuild((ref, notifier) {
    return CelestialCatalogViewState(
      totalObjects: 0,
      query: '',
      category: null,
      results: const [],
    );
  });
}
