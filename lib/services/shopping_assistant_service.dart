import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'api_service.dart';

class ShoppingAssistantException implements Exception {
  const ShoppingAssistantException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShoppingSuggestions {
  const ShoppingSuggestions({
    required this.products,
    required this.message,
    required this.notice,
    required this.question,
    required this.maxPrice,
    required this.limited,
  });
  final List<Product> products;
  final String message, notice;
  final String? question;
  final double? maxPrice;
  final bool limited;
  factory ShoppingSuggestions.fromJson(Map<String, dynamic> data) {
    if (data['source'] != 'naijago_catalog' ||
        data['budgetScope'] != 'per_listing' ||
        data['deliveryIncluded'] != false ||
        data['products'] is! List ||
        (data['products'] as List).length > 12 ||
        data['message'] is! String ||
        data['notice'] is! String ||
        (data['question'] != null && data['question'] is! String) ||
        data['limitedResults'] is! bool) {
      throw const FormatException('Invalid shopping suggestions.');
    }
    final maxPrice = data['maxPrice'] == null
        ? null
        : (data['maxPrice'] as num).toDouble();
    if (maxPrice != null && (!maxPrice.isFinite || maxPrice <= 0)) {
      throw const FormatException('Invalid budget.');
    }
    final ids = <String>{};
    final products = (data['products'] as List)
        .map((row) {
          if (row is! Map) throw const FormatException('Invalid listing.');
          final product = Product.fromJson(Map<String, dynamic>.from(row));
          if (product.id.isEmpty ||
              !product.isActive ||
              !product.price.isFinite ||
              product.price < 0 ||
              product.stockQuantity <= 0 ||
              (maxPrice != null && product.price > maxPrice)) {
            throw const FormatException('Invalid listing price or stock.');
          }
          return product;
        })
        .where((product) => ids.add('${product.id}:${product.offerId ?? ''}'))
        .toList();
    return ShoppingSuggestions(
      products: products,
      message: data['message'],
      notice: data['notice'],
      question: data['question'],
      maxPrice: maxPrice,
      limited: data['limitedResults'],
    );
  }
}

class ShoppingAssistantService {
  ShoppingAssistantService({Future<http.Response> Function(String, Map)? post})
    : _post = post ?? ApiService.post;
  final Future<http.Response> Function(String, Map) _post;
  Future<ShoppingSuggestions> suggest(String message) async {
    final text = message.trim();
    if (text.length < 2 || text.length > 500) {
      throw const ShoppingAssistantException(
        'Describe what you need in 2–500 characters.',
      );
    }
    try {
      final response = await _post('/api/products/shopping-assistant', {
        'message': text,
      }).timeout(const Duration(seconds: 40));
      if (response.statusCode == 404) {
        throw const ShoppingAssistantException(
          'Shopping Assistant is not available on this server yet. Normal search is still available.',
        );
      }
      if (response.statusCode == 429) {
        throw const ShoppingAssistantException(
          'The assistant is busy. Wait a minute and try again.',
        );
      }
      if (response.statusCode != 200) {
        throw const ShoppingAssistantException(
          'Shopping Assistant is temporarily unavailable. You can still use normal search.',
        );
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid response.');
      }
      return ShoppingSuggestions.fromJson(data);
    } on ShoppingAssistantException {
      rethrow;
    } on TimeoutException {
      throw const ShoppingAssistantException(
        'The request took too long. Try again or use normal search.',
      );
    } on http.ClientException {
      throw const ShoppingAssistantException(
        'Check your connection and try again.',
      );
    } catch (_) {
      throw const ShoppingAssistantException(
        'Could not load shopping suggestions. Please try again.',
      );
    }
  }
}
