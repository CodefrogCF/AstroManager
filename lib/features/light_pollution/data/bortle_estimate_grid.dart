import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A compact lookup for the precomputed VIIRS zenith brightness model.
final class BortleEstimateGrid {
  const BortleEstimateGrid._(
    this._archive,
    this.datasetYear,
    this._north,
    this._south,
    this._bandDegrees,
    this._cellsPerDegree,
  );

  factory BortleEstimateGrid.fromZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final rawMetadata = archive.findFile('metadata.json')?.readBytes();
    if (rawMetadata == null) {
      throw const FormatException('Missing Bortle grid metadata.');
    }
    final metadata = jsonDecode(utf8.decode(rawMetadata));
    if (metadata
        case {
          'version': 1,
          'datasetYear': final int year,
          'north': final int north,
          'south': final int south,
          'bandDegrees': final int bandDegrees,
          'cellsPerDegree': final int cellsPerDegree,
        }
        when south >= -90 &&
            north <= 90 &&
            north > south &&
            bandDegrees > 0 &&
            (north - south) % bandDegrees == 0 &&
            cellsPerDegree > 0) {
      return BortleEstimateGrid._(
        archive,
        year,
        north,
        south,
        bandDegrees,
        cellsPerDegree,
      );
    }
    throw const FormatException('Invalid Bortle grid metadata.');
  }

  final Archive _archive;
  final int datasetYear;
  final int _north;
  final int _south;
  final int _bandDegrees;
  final int _cellsPerDegree;

  /// Code 8 represents the combined 8–9 class. Code 0 is outside coverage.
  int? classAt({required double latitude, required double longitude}) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude <= _south ||
        latitude > _north ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    final row = ((_north - latitude) * _cellsPerDegree).floor();
    final width = 360 * _cellsPerDegree;
    final column = ((longitude + 180) * _cellsPerDegree).floor() % width;
    final rowsPerBand = _bandDegrees * _cellsPerDegree;
    final band = _archive.findFile('${row ~/ rowsPerBand}.bin')?.readBytes();
    if (band == null || band.length != width * rowsPerBand) {
      throw const FormatException('Invalid Bortle grid band.');
    }
    final value = band[(row % rowsPerBand) * width + column];
    return value >= 2 && value <= 8 ? value : null;
  }
}
