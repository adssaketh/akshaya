import 'dart:async';
import 'dart:convert';

import 'package:akshaya/features/scanning/data/open_food_facts_client.dart';
import 'package:akshaya/features/scanning/domain/product_info.dart';
import 'package:akshaya/features/scanning/domain/product_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(Object body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

OpenFoodFactsClient clientFor(
  Future<http.Response> Function(http.Request request) handler, {
  Duration timeout = const Duration(seconds: 2),
}) {
  return OpenFoodFactsClient(client: MockClient(handler), timeout: timeout);
}

void main() {
  group('fetch', () {
    test('reads a product and asks only for the fields it uses', () async {
      late http.Request seen;
      final OpenFoodFactsClient client = clientFor((http.Request request) async {
        seen = request;
        return json(<String, Object?>{
          'status': 1,
          'product': <String, Object?>{
            'product_name': 'Beurre',
            'product_name_en': 'Salted Butter',
            'brands': 'Amul, Other',
            'quantity': '500 g',
            'categories_tags': <String>['en:dairies', 'en:butters'],
          },
        });
      });

      final ProductInfo? info = await client.fetch('8901262010013');

      expect(info, isNotNull);
      expect(info!.name, 'Salted Butter');
      expect(info.brand, 'Amul');
      expect(info.quantityText, '500 g');
      expect(info.categoryTags, <String>['en:dairies', 'en:butters']);

      expect(seen.url.host, 'world.openfoodfacts.org');
      expect(seen.url.path, '/api/v2/product/8901262010013.json');
      expect(seen.url.queryParameters['fields'], contains('product_name'));
      expect(seen.headers['User-Agent'], OpenFoodFactsClient.userAgent);
      // Nothing personal goes out.
      expect(seen.headers.keys.map((String k) => k.toLowerCase()),
          isNot(contains('authorization')));
      expect(seen.headers.keys.map((String k) => k.toLowerCase()),
          isNot(contains('cookie')));
    });

    test('falls back to product_name when there is no English name', () async {
      final OpenFoodFactsClient client = clientFor((_) async => json(
            <String, Object?>{
              'status': 1,
              'product': <String, Object?>{'product_name': 'Atta'},
            },
          ));
      expect((await client.fetch('4006381333931'))!.name, 'Atta');
    });

    test('returns null for an unknown barcode (status 0 and 404)', () async {
      final OpenFoodFactsClient notFound = clientFor((_) async => json(
            <String, Object?>{'status': 0, 'status_verbose': 'not found'},
          ));
      expect(await notFound.fetch('4006381333931'), isNull);

      final OpenFoodFactsClient http404 = clientFor((_) async => json(
            <String, Object?>{'status': 0},
            404,
          ));
      expect(await http404.fetch('4006381333931'), isNull);
    });

    test('returns null for a product without a usable name', () async {
      final OpenFoodFactsClient client = clientFor((_) async => json(
            <String, Object?>{
              'status': 1,
              'product': <String, Object?>{'product_name': '  ', 'brands': 'X'},
            },
          ));
      expect(await client.fetch('4006381333931'), isNull);
    });

    test('is unavailable on server errors, rate limits and bad bodies',
        () async {
      for (final int status in <int>[429, 500, 503, 403]) {
        final OpenFoodFactsClient client =
            clientFor((_) async => json(<String, Object?>{}, status));
        await expectLater(
          client.fetch('4006381333931'),
          throwsA(isA<LookupUnavailableException>()),
          reason: 'HTTP $status',
        );
      }

      final OpenFoodFactsClient garbage =
          clientFor((_) async => http.Response('<html>', 200));
      await expectLater(
        garbage.fetch('4006381333931'),
        throwsA(isA<LookupUnavailableException>()),
      );
    });

    test('is unavailable when offline or too slow', () async {
      final OpenFoodFactsClient offline = clientFor(
        (_) async => throw http.ClientException('no route to host'),
      );
      await expectLater(
        offline.fetch('4006381333931'),
        throwsA(isA<LookupUnavailableException>()),
      );

      final OpenFoodFactsClient slow = clientFor(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        slow.fetch('4006381333931'),
        throwsA(isA<LookupUnavailableException>()),
      );
    });
  });

  group('parseProduct', () {
    test('ignores anything that is not an API answer', () {
      expect(OpenFoodFactsClient.parseProduct(null), isNull);
      expect(OpenFoodFactsClient.parseProduct('x'), isNull);
      expect(OpenFoodFactsClient.parseProduct(<String, Object?>{}), isNull);
      expect(
        OpenFoodFactsClient.parseProduct(
          <String, Object?>{'status': 1, 'product': 'oops'},
        ),
        isNull,
      );
    });

    test('accepts status given as text', () {
      final ProductInfo? info = OpenFoodFactsClient.parseProduct(
        <String, Object?>{
          'status': '1',
          'product': <String, Object?>{'product_name': 'Salt'},
        },
      );
      expect(info!.name, 'Salt');
    });
  });
}
