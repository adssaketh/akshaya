import 'dart:convert';

import 'package:drift/drift.dart';

import '../../pantry/data/database/app_database.dart';
import '../domain/product_info.dart';
import '../domain/product_lookup.dart';
import 'open_food_facts_client.dart';

/// Looks products up on Open Food Facts and remembers the answers.
///
/// - A known product is cached for [foundTtl]; an unknown barcode for the
///   shorter [notFoundTtl] (someone may add it to Open Food Facts).
/// - When the network fails, an older cached product is still used.
/// - Failures are never cached and never thrown.
class CachedProductLookup implements ProductLookup {
  CachedProductLookup({
    required this._db,
    required this._remote,
    DateTime Function()? clock,
    this.foundTtl = const Duration(days: 30),
    this.notFoundTtl = const Duration(days: 1),
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final OpenFoodFactsClient _remote;
  final DateTime Function() _clock;
  final Duration foundTtl;
  final Duration notFoundTtl;

  @override
  Future<LookupResult> lookup(String barcode) async {
    final ProductCacheRow? cached = await (_db.select(_db.productCache)
          ..where((t) => t.barcode.equals(barcode)))
        .getSingleOrNull();
    final ProductInfo? cachedInfo = _readCache(cached);

    if (cached != null) {
      final Duration age = _clock().difference(cached.fetchedAt);
      if (cached.found && cachedInfo != null && age < foundTtl) {
        return LookupFound(cachedInfo);
      }
      if (!cached.found && age < notFoundTtl) {
        return const LookupNotFound();
      }
    }

    final ProductInfo? info;
    try {
      info = await _remote.fetch(barcode);
    } on Object catch (_) {
      // Offline, timed out or refused: an old answer beats no answer.
      return cachedInfo == null
          ? const LookupUnavailable()
          : LookupFound(cachedInfo);
    }

    try {
      await _store(barcode, info);
    } on Object catch (_) {
      // The cache is a convenience; a failed write must not hide the answer.
    }
    return info == null ? const LookupNotFound() : LookupFound(info);
  }

  ProductInfo? _readCache(ProductCacheRow? row) {
    final String? payload = row?.payload;
    if (row == null || !row.found || payload == null) {
      return null;
    }
    try {
      return ProductInfo.fromJson(jsonDecode(payload));
    } on FormatException {
      return null;
    }
  }

  Future<void> _store(String barcode, ProductInfo? info) {
    return _db.into(_db.productCache).insertOnConflictUpdate(
          ProductCacheCompanion.insert(
            barcode: barcode,
            found: info != null,
            payload:
                Value<String?>(info == null ? null : jsonEncode(info.toJson())),
            fetchedAt: _clock(),
          ),
        );
  }
}
