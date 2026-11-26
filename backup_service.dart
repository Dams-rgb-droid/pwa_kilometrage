import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import 'file_delivery.dart';

class BackupContent {
  const BackupContent(this.trips, {this.skipped = 0});
  final List<Trip> trips;
  final int skipped;
}

class BackupService {
  static const String _appId = 'kilometrage-pro';

  String buildBackup(List<Trip> trips) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': _appId,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'trips': trips.map((trip) => trip.toJson()).toList(),
    });
  }

  Future<DeliveryResult> saveBackup(List<Trip> trips) {
    final name =
        'sauvegarde_kilometrage_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    return deliverFile(
      name: name,
      extension: 'json',
      mimeTypeName: 'application/json',
      mimeType: MimeType.json,
      bytes: Uint8List.fromList(utf8.encode(buildBackup(trips))),
    );
  }

  /// Lit une sauvegarde. Lève une FormatException si le fichier n'est pas
  /// une sauvegarde valide ou ne contient aucun relevé lisible.
  BackupContent parseBackup(String text) {
    final Object? decoded;
    try {
      decoded = json.decode(text);
    } catch (_) {
      throw const FormatException('Ce fichier n’est pas une sauvegarde valide.');
    }

    final Object? list = decoded is Map ? decoded['trips'] : decoded;
    if (list is! List) {
      throw const FormatException('Ce fichier n’est pas une sauvegarde valide.');
    }

    final trips = <Trip>[];
    var skipped = 0;
    for (final item in list) {
      try {
        trips.add(Trip.fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (_) {
        skipped++;
      }
    }
    if (trips.isEmpty && list.isNotEmpty) {
      throw const FormatException('Aucun relevé lisible dans ce fichier.');
    }
    return BackupContent(trips, skipped: skipped);
  }
}
