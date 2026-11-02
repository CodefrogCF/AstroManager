import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/light_pollution.dart';

/// Esri-hosted global VIIRS monthly cloud-free mosaic (data: NOAA / EOG).
/// The *raw* radiance function must be requested: stretched imagery pixels
/// cannot be interpreted as physical radiance.
final class ArcGisViirsProvider implements LightPollutionProvider {
  ArcGisViirsProvider({http.Client? client})
    : _client = client ?? http.Client();

  static const endpoint =
      'https://di-lawimagery1.img.arcgis.com/arcgis/rest/services/'
      'NighttimeLightsMDNB/ImageServer/identify';
  static const sourcePage =
      'https://www.arcgis.com/home/item.html?id=edabcbb5407547f5bc883018eb6e7986';
  // Pinned, completed monthly layer; do not label it as a current-night result.
  static final sampleMonth = DateTime.utc(2025, 12, 31);
  final http.Client _client;

  @override
  String get id => 'esri-eog-viirs-monthly-2025-12-raw-v1';

  void close() => _client.close();

  Uri identifyUri({
    required double latitude,
    required double longitude,
    required String rasterFunction,
  }) {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Coordinates must be valid WGS84 degrees.');
    }
    return Uri.parse(endpoint).replace(
      queryParameters: {
        'f': 'json',
        'geometry': jsonEncode({
          'x': longitude,
          'y': latitude,
          'spatialReference': {'wkid': 4326},
        }),
        'geometryType': 'esriGeometryPoint',
        'returnGeometry': 'false',
        'returnCatalogItems': 'true',
        'time':
            '${DateTime.utc(2025, 12, 1).millisecondsSinceEpoch},'
            '${DateTime.utc(2026, 1, 1).millisecondsSinceEpoch - 1}',
        'mosaicRule': jsonEncode({
          'mosaicMethod': 'esriMosaicAttribute',
          'where': 'year = 2025 AND month = 12',
          'sortField': 'end_date',
          'sortValue': '2025/12/31',
        }),
        'renderingRule': jsonEncode({'rasterFunction': rasterFunction}),
      },
    );
  }

  /// Ignore NoData/sentinel values, malformed samples and service errors.
  /// `0` is legitimate only when paired with at least one cloud-free sample.
  static double? parsePixel(Map<String, dynamic> response) {
    if (response.containsKey('error')) {
      throw FormatException('VIIRS ArcGIS API error: ${response['error']}');
    }
    final raw = response['value'];
    final number = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (raw == null ||
        raw == 'NoData' ||
        number == null ||
        !number.isFinite ||
        number < 0 ||
        number >= 1.0e20) {
      return null;
    }
    return number;
  }

  Future<Map<String, dynamic>> _request(Uri uri) async {
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('VIIRS request failed (HTTP ${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected VIIRS response format.');
    }
    return decoded;
  }

  @override
  Future<LightPollutionReading?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    // Coverage MUST be checked, especially at high latitudes. Never classify
    // a zero radiance pixel with zero clear-sky observations as a dark site.
    final results = await Future.wait([
      _request(
        identifyUri(
          latitude: latitude,
          longitude: longitude,
          rasterFunction: 'Average Monthly Radiance (Raw Values)',
        ),
      ),
      _request(
        identifyUri(
          latitude: latitude,
          longitude: longitude,
          rasterFunction: 'Monthly Cloud Free Observations',
        ),
      ),
    ]);
    final radiance = parsePixel(results[0]);
    final coverage = parsePixel(results[1]);
    if (radiance == null || coverage == null || coverage < 1) return null;
    final result = LightPollutionReading(
      kind: NightLightKind.satelliteRadiance,
      value: radiance,
      sourceId: id,
      sourceName: 'VIIRS DNB monthly composite (EOG / NOAA via Esri)',
      datasetDate: sampleMonth,
      latitude: latitude,
      longitude: longitude,
      description:
          'December 2025 monthly upward radiance; '
          '${coverage.toStringAsFixed(0)} cloud-free observations. '
          'Not a sky brightness measurement or a Bortle class.',
      sourceUrl: sourcePage,
      sourceCatalogUpdatedAt: DateTime.utc(2026, 5, 28),
      license:
          'Source: Earth Observation Group / NOAA; Esri imagery service. '
          'Check upstream reuse terms before republishing tiles.',
    );
    result.validate();
    return result;
  }
}
