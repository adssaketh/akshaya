import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/product_info.dart';
import '../domain/product_lookup.dart';

/// Reads one product from the Open Food Facts API (no key needed).
///
/// Returns null when the barcode is unknown and throws
/// [LookupUnavailableException] when no answer could be had.
class OpenFoodFactsClient {
  OpenFoodFactsClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
    this.host = 'world.openfoodfacts.org',
  }) : _client = client ?? http.Client();

  /// Open Food Facts asks apps to identify themselves. No personal details
  /// are sent.
  static const String userAgent = 'AkshayaPatra/0.1 (Android; pantry app)';

  /// Only the fields we use, which keeps the answer small.
  static const String _fields =
      'product_name,product_name_en,brands,quantity,categories_tags';

  final http.Client _client;
  final Duration timeout;
  final String host;

  Future<ProductInfo?> fetch(String barcode) async {
    final Uri uri = Uri.https(
      host,
      '/api/v2/product/$barcode.json',
      <String, String>{'fields': _fields},
    );

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const <String, String>{
          'User-Agent': userAgent,
          'Accept': 'application/json',
        },
      ).timeout(timeout);
    } on Object catch (_) {
      throw const LookupUnavailableException();
    }

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw const LookupUnavailableException();
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const LookupUnavailableException();
    }
    return parseProduct(decoded);
  }

  /// Reads the API answer. Returns null when the product is unknown or has
  /// no usable name.
  static ProductInfo? parseProduct(Object? decoded) {
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final Object? status = decoded['status'];
    if (status != 1 && status != '1') {
      return null;
    }
    final Object? product = decoded['product'];
    if (product is! Map<String, Object?>) {
      return null;
    }

    final String? name =
        _text(product['product_name_en']) ?? _text(product['product_name']);
    if (name == null) {
      return null;
    }
    final String? brands = _text(product['brands']);
    final Object? tags = product['categories_tags'];

    return ProductInfo(
      name: name,
      brand: brands?.split(',').first.trim(),
      quantityText: _text(product['quantity']),
      categoryTags: tags is List<Object?>
          ? <String>[
              for (final Object? tag in tags)
                if (tag is String) tag,
            ]
          : const <String>[],
    );
  }

  static String? _text(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void close() => _client.close();
}
