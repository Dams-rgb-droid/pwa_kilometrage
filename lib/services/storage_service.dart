// lib/services/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';

class StorageLoadResult {
  const StorageLoadResult(
    this.trips, {
    this.skipped = 0,
    this.unreadable = false,
  });

  final List<Trip> trips;

  /// Nombre de relevés illisibles ignorés.
  final int skipped;

  /// Vrai si l'ensemble des données était illisible.
  final bool unreadable;

  bool get hasProblem => skipped > 0 || unreadable;
}

class StorageService {
  static const String _key = 'my_trips_key';
  // Copie de sécurité des données illisibles, jamais écrasée automatiquement.
  static const String _unreadableKey = 'my_trips_key_unreadable';

  Future<void> saveTrips(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      trips.map((trip) => trip.toJson()).toList(),
    );
    await prefs.setString(_key, encodedData);
  }

  /// Ne lève pas d'exception sur des données corrompues : l'application doit
  /// toujours pouvoir démarrer.
  Future<StorageLoadResult> loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return StorageLoadResult([]);

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) throw const FormatException('Format inattendu');

      final trips = <Trip>[];
      var skipped = 0;
      for (final item in decoded) {
        try {
          trips.add(Trip.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {
          skipped++;
        }
      }
      if (skipped > 0) await prefs.setString(_unreadableKey, raw);
      return StorageLoadResult(trips, skipped: skipped);
    } catch (_) {
      await prefs.setString(_unreadableKey, raw);
      return StorageLoadResult([], unreadable: true);
    }
  }
}
