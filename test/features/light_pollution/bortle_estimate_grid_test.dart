import 'package:astromanager/features/light_pollution/data/bortle_estimate_grid.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BortleEstimateGrid grid;

  setUpAll(() async {
    final bytes = await rootBundle.load(
      'assets/light_pollution/bortle_2024.zip',
    );
    grid = BortleEstimateGrid.fromZip(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  });

  test(
    'bundled VIIRS model has different classes for urban and dark sites',
    () {
      expect(grid.datasetYear, 2024);
      final manhattan = grid.classAt(latitude: 40.713, longitude: -74.006);
      final greatBasin = grid.classAt(latitude: 38.98, longitude: -114.30);
      final berlin = grid.classAt(latitude: 52.52, longitude: 13.405);
      final namib = grid.classAt(latitude: -24, longitude: 16);
      expect(manhattan, greaterThanOrEqualTo(7));
      expect(berlin, greaterThanOrEqualTo(5));
      expect(greatBasin, lessThanOrEqualTo(3));
      expect(namib, lessThanOrEqualTo(3));
    },
  );

  test('lookup handles the dateline and sites outside the raster', () {
    expect(
      grid.classAt(latitude: 0, longitude: 180),
      grid.classAt(latitude: 0, longitude: -180),
    );
    expect(grid.classAt(latitude: 76, longitude: 20), isNull);
    expect(grid.classAt(latitude: -61, longitude: 0), isNull);
    expect(grid.classAt(latitude: double.nan, longitude: 0), isNull);
    expect(grid.classAt(latitude: 0, longitude: 181), isNull);
  });
}
