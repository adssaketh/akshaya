import 'dart:convert';

import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/scanning/data/cached_product_lookup.dart';
import 'package:akshaya/features/scanning/data/open_food_facts_client.dart';
import 'package:akshaya/features/scanning/domain/product_lookup.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const String barcode = '8901262010013';

  late AppDatabase db;
  late DateTime now;
  late int calls;
  late bool online;
  late Object? answer;

  http.Response ok(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );

  Map<String, Object?> butter() => <String, Object?>{
        'status': 1,
        'product': <String, Object?>{
          'product_name_en': 'Salted Butter',
          'brands': 'Amul',
          'quantity': '500 g',
          'categories_tags': <String>['en:butters'],
        },
      };

  CachedProductLookup build() {
    final MockClient client = MockClient((http.Request request) async {
      calls++;
      if (!online) {
        throw http.ClientException('offline');
      }
      return ok(answer!);
    });
    return CachedProductLookup(
      db: db,
      remote: OpenFoodFactsClient(client: client),
      clock: () => now,
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 11, 4, 10);
    calls = 0;
    online = true;
    answer = butter();
  });

  tearDown(() => db.close());

  test('looks a product up once, then answers from the cache', () async {
    final CachedProductLookup lookup = build();

    final LookupResult first = await lookup.lookup(barcode);
    expect(first, isA<LookupFound>());
    expect((first as LookupFound).info.name, 'Salted Butter');
    expect(calls, 1);

    online = false;
    final LookupResult second = await lookup.lookup(barcode);
    expect((second as LookupFound).info.brand, 'Amul');
    expect(calls, 1, reason: 'served from the cache, no request');
  });

  test('looks again after a found product is 30 days old', () async {
    final CachedProductLookup lookup = build();
    await lookup.lookup(barcode);

    now = now.add(const Duration(days: 31));
    answer = <String, Object?>{
      'status': 1,
      'product': <String, Object?>{'product_name': 'Butter, renamed'},
    };
    final LookupResult again = await lookup.lookup(barcode);
    expect((again as LookupFound).info.name, 'Butter, renamed');
    expect(calls, 2);
  });

  test('uses an out-of-date answer when the network is down', () async {
    final CachedProductLookup lookup = build();
    await lookup.lookup(barcode);

    now = now.add(const Duration(days: 90));
    online = false;
    final LookupResult result = await lookup.lookup(barcode);
    expect(result, isA<LookupFound>());
    expect((result as LookupFound).info.name, 'Salted Butter');
  });

  test('remembers an unknown barcode for a day, then asks again', () async {
    answer = <String, Object?>{'status': 0};
    final CachedProductLookup lookup = build();

    expect(await lookup.lookup(barcode), isA<LookupNotFound>());
    expect(await lookup.lookup(barcode), isA<LookupNotFound>());
    expect(calls, 1);

    now = now.add(const Duration(days: 2));
    answer = butter();
    expect(await lookup.lookup(barcode), isA<LookupFound>());
    expect(calls, 2);
  });

  test('offline with nothing cached is unavailable and is not cached', () async {
    online = false;
    final CachedProductLookup lookup = build();

    expect(await lookup.lookup(barcode), isA<LookupUnavailable>());

    online = true;
    expect(await lookup.lookup(barcode), isA<LookupFound>());
    expect(calls, 2, reason: 'the failure must not have been remembered');
  });

  test('an unreadable cache row is ignored and replaced', () async {
    final CachedProductLookup lookup = build();
    await db.customStatement(
      'INSERT INTO product_cache (barcode, found, payload, fetched_at) '
      "VALUES ('$barcode', 1, '{not json', ${now.millisecondsSinceEpoch})",
    );

    final LookupResult result = await lookup.lookup(barcode);
    expect(result, isA<LookupFound>());
    expect((result as LookupFound).info.name, 'Salted Butter');
    expect(calls, 1);
  });
}
