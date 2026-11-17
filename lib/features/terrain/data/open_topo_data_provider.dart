import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/terrain_horizon.dart';

/// OpenTopoData public endpoint; the EU-DEM dataset covers Switzerland.
/// Respect its published <=100 points/request and <=1 request/second limits.
/// Can be replaced by a self-hosted OpenTopoData instance without changing
/// the rest of the application.
final class OpenTopoDataElevationProvider implements TerrainElevationProvider {
  OpenTopoDataElevationProvider({
    http.Client? client,
    this.baseUrl = 'https://api.opentopodata.org',
    this.dataset = 'eudem25m',
    this.batchSize = 90,
    this.betweenRequests = const Duration(milliseconds: 1100),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (batchSize < 1 || batchSize > 100) {
      throw ArgumentError.value(batchSize, 'batchSize', 'Must be 1 to 100.');
    }
  }

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final String dataset;
  final int batchSize;
  final Duration betweenRequests;
  Future<void> _nextRequestSlot = Future<void>.value();

  @override
  String get id => 'opentopodata:${Uri.parse(baseUrl).host}:$dataset';

  @override
  Future<List<double?>> elevations(List<TerrainPoint> points) async {
    final heights = <double?>[];
    for (var start = 0; start < points.length; start += batchSize) {
      final batch = points.skip(start).take(batchSize).toList();
      final locations = batch
          .map(
            (p) =>
                '${p.latitude.toStringAsFixed(7)},${p.longitude.toStringAsFixed(7)}',
          )
          .join('|');
      final uri = Uri.parse('$baseUrl/v1/$dataset').replace(
        queryParameters: {'locations': locations, 'interpolation': 'bilinear'},
      );
      final response = await _get(uri);
      if (response.statusCode != 200) {
        throw StateError(
          'Elevation service returned HTTP ${response.statusCode}.',
        );
      }
      final Object? payload;
      try {
        payload = jsonDecode(response.body);
      } on FormatException {
        throw const FormatException('Malformed elevation service response.');
      }
      if (payload is! Map<String, dynamic> ||
          payload['status'] != 'OK' ||
          payload['results'] is! List) {
        throw const FormatException('Unexpected elevation service response.');
      }
      final results = payload['results'] as List;
      if (results.length != batch.length) {
        throw const FormatException(
          'Elevation response count does not match request.',
        );
      }
      for (final item in results) {
        if (item is! Map ||
            (item['elevation'] != null && item['elevation'] is! num)) {
          throw const FormatException('Invalid elevation result.');
        }
        final elevation = (item['elevation'] as num?)?.toDouble();
        heights.add(elevation != null && elevation.isFinite ? elevation : null);
      }
    }
    return heights;
  }

  Future<http.Response> _get(Uri uri) async {
    if (betweenRequests > Duration.zero) {
      // Share the rate limit across batches and concurrent site requests.
      final slot = _nextRequestSlot;
      _nextRequestSlot = slot.then(
        (_) => Future<void>.delayed(betweenRequests),
      );
      await slot;
    }
    try {
      return await _client.get(uri).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw StateError('Elevation request timed out.');
    } on Exception {
      throw StateError('Elevation network request failed.');
    }
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
