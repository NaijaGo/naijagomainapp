import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/deal.dart';
import '../models/product.dart';
import 'api_service.dart';

class DealsException implements Exception {
  const DealsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DealsService {
  DealsService({Future<http.Response> Function(String)? get})
    : _get = get ?? ApiService.get;
  final Future<http.Response> Function(String) _get;
  Future<Map<String, dynamic>> _request(String path) async {
    try {
      final response = await _get(path).timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw const DealsException(
          'This Deal is no longer available, or Deals are not available on this server yet.',
        );
      }
      if (response.statusCode != 200) {
        throw const DealsException(
          'Deals are temporarily unavailable. Please try again.',
        );
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid response.');
      }
      return data;
    } on DealsException {
      rethrow;
    } on TimeoutException {
      throw const DealsException(
        'Check your connection and try loading Deals again.',
      );
    } on http.ClientException {
      throw const DealsException(
        'Check your connection and try loading Deals again.',
      );
    } catch (_) {
      throw const DealsException(
        'Deals are temporarily unavailable. Please try again.',
      );
    }
  }

  Future<DealPage> list({int page = 1, int limit = 20}) async {
    if (page < 1 || page > 1000 || limit < 1 || limit > 50) {
      throw const DealsException('Unable to load this Deals page.');
    }
    try {
      final result = DealPage.fromJson(
        await _request('/api/deals?page=$page&limit=$limit'),
      );
      if (result.page != page) throw const FormatException('Unexpected page.');
      return result;
    } on DealsException {
      rethrow;
    } catch (_) {
      throw const DealsException(
        'Deals are temporarily unavailable. Please try again.',
      );
    }
  }

  Future<Product> productForDeal(Deal selected) async {
    try {
      final detail = await _request('/api/deals/${selected.id}');
      if (detail['deal'] is! Map) throw const FormatException('Missing Deal.');
      final deal = Deal.fromJson(Map<String, dynamic>.from(detail['deal']));
      final now =
          Deal.parseDate(detail['serverTime']) ?? DateTime.now().toUtc();
      if (deal.id != selected.id || !deal.isActiveAt(now)) {
        throw const DealsException(
          'This Deal has ended. Refresh Deals to see current offers.',
        );
      }
      final elapsed = Stopwatch()..start();
      final data = await _request('/api/products/${deal.productId}');
      if (!deal.isActiveAt(now.add(elapsed.elapsed))) {
        throw const DealsException(
          'This Deal has ended. Refresh Deals to see current offers.',
        );
      }
      if (data['_id'] != deal.productId || data['isActive'] != true) {
        throw const DealsException('This product is no longer available.');
      }
      Map<String, dynamic> resolved = data;
      if (deal.offerId != null) {
        final offers = data['offers'];
        if (offers is! List) {
          throw const DealsException(
            'This product offer is no longer available.',
          );
        }
        final matches = offers.whereType<Map>().where(
          (row) => row['_id'] == deal.offerId,
        );
        if (matches.length != 1) {
          throw const DealsException(
            'This product offer is no longer available.',
          );
        }
        final offer = Map<String, dynamic>.from(matches.single);
        final vendor = offer['sellerId'];
        final vendorId = vendor is Map ? vendor['_id'] : vendor;
        if (offer['status'] != 'active' ||
            vendorId != deal.vendorId ||
            offer['deal'] is! Map ||
            (offer['deal'] as Map)['dealId'] != deal.id) {
          throw const DealsException(
            'This Deal has changed. Refresh Deals before shopping.',
          );
        }
        resolved = {
          ...data,
          'selectedOffer': offer,
          'price': offer['price'],
          'discountPrice': offer['discountPrice'],
          'effectivePrice': offer['effectivePrice'],
          'stockQuantity': offer['stockQuantity'],
          'sellerType': offer['sellerType'],
          'sellerId': vendorId,
          'sellerName': deal.vendorName,
          'vendor': vendor is Map ? vendor : data['vendor'],
        };
      } else if (data['deal'] is! Map ||
          (data['deal'] as Map)['dealId'] != deal.id) {
        throw const DealsException(
          'This Deal has changed. Refresh Deals before shopping.',
        );
      }
      // All price and offer fields above come from the current product API.
      // The partial Deals card response is never turned into a checkout product.
      final product = Product.fromJson(resolved);
      if (!product.price.isFinite ||
          product.price < 0 ||
          product.stockQuantity <= 0) {
        throw const DealsException(
          'This product offer is no longer available.',
        );
      }
      return product;
    } on DealsException {
      rethrow;
    } catch (_) {
      throw const DealsException('Could not open this Deal. Please try again.');
    }
  }
}
