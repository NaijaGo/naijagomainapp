import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;
  final dynamic selectedSize;
  final String? selectedColor;
  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedSize,
    this.selectedColor,
  });

  Map<String, dynamic> toJson() => {
    'product': product.id,
    if (product.offerId != null) 'offer': product.offerId,
    'name': product.name,
    'image': product.imageUrls.isNotEmpty
        ? product.imageUrls.first
        : 'https://placehold.co/100x100/CCCCCC/000000?text=No+Image',
    'quantity': quantity,
    'price': product.price,
    'sellerType': product.sellerType,
    'sellerId': product.sellerId,
    'sellerName': product.sellerName,
    'vendor': product.sellerType == 'vendor' ? product.vendorId : null,
    'selectedSize': selectedSize,
    'selectedColor': ?selectedColor,
  };
  String get displayName {
    final size = selectedSize is Map
        ? (selectedSize['label'] ??
                  selectedSize['value'] ??
                  'Custom dimensions')
              .toString()
        : selectedSize?.toString();
    final options = [
      ?selectedColor,
      if (size != null && size.isNotEmpty) size,
    ];
    return options.isEmpty
        ? product.name
        : '${product.name} (${options.join(', ')})';
  }
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  Map<String, CartItem> get items => {..._items};
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount => _items.values.fold(
    0,
    (sum, item) => sum + item.quantity * item.product.price,
  );
  String _restaurantOrderNote = '';

  String get restaurantOrderNote => _restaurantOrderNote;

  void setRestaurantOrderNote(String value) {
    final sanitized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    _restaurantOrderNote = sanitized.length > 500
        ? sanitized.substring(0, 500)
        : sanitized;
    notifyListeners();
  }

  CartItem? restaurantVendorConflict(Product product) {
    if (!product.isRestaurantItem) return null;

    for (final item in _items.values) {
      if (item.product.isRestaurantItem &&
          item.product.vendorId.isNotEmpty &&
          product.vendorId.isNotEmpty &&
          item.product.vendorId != product.vendorId) {
        return item;
      }
    }

    return null;
  }

  static String _key(String productId, dynamic size, String? color) {
    if (size == null && color == null) return productId;
    final normalized = size is Map
        ? (size.keys.map((key) => key.toString()).toList()..sort()).asMap().map(
            (_, key) => MapEntry(key, size[key]),
          )
        : size;
    return '$productId:${jsonEncode([normalized, color])}';
  }

  bool addProduct(
    Product product, {
    dynamic selectedSize,
    String? selectedColor,
  }) {
    if (product.hasColors && !product.availableColors.contains(selectedColor)) {
      return false;
    }
    if (!product.hasColors && selectedColor != null) return false;
    if (product.hasSizes && selectedSize == null) return false;
    if (product.hasSizes && !product.isCustomDimensions) {
      final size = selectedSize is Map ? selectedSize['value'] : selectedSize;
      if (!product.availableSizes.contains(size)) return false;
    }
    if (product.isCustomDimensions && selectedSize != null) {
      final dimensions = product.sizeData?['customDimensions'] as List? ?? [];
      if (selectedSize is! Map ||
          !dimensions.any(
            (dim) =>
                dim is Map &&
                ['length', 'width', 'height', 'unit', 'label'].every(
                  (field) =>
                      '${dim[field] ?? ''}' == '${selectedSize[field] ?? ''}',
                ),
          )) {
        return false;
      }
    }
    if (restaurantVendorConflict(product) != null) return false;
    if (_items.values.any(
      (item) =>
          item.product.id == product.id &&
          (item.product.offerId != product.offerId ||
              item.product.sellerId != product.sellerId),
    )) {
      return false;
    }
    final alreadyAdded = _items.values
        .where((item) => item.product.id == product.id)
        .fold(0, (sum, item) => sum + item.quantity);
    if (alreadyAdded >= product.stockQuantity) return false;
    final key = _key(product.id, selectedSize, selectedColor);
    final existing = _items[key];
    if (existing != null) {
      if (existing.product.offerId != product.offerId ||
          existing.product.sellerId != product.sellerId) {
        return false;
      }
      existing.quantity++;
    } else {
      _items[key] = CartItem(
        product: product,
        selectedSize: selectedSize,
        selectedColor: selectedColor,
      );
    }
    notifyListeners();
    return true;
  }

  void removeSingleItem(
    String productId, {
    dynamic selectedSize,
    String? selectedColor,
  }) {
    final key = _items.containsKey(productId)
        ? productId
        : _key(productId, selectedSize, selectedColor);
    final item = _items[key];
    if (item == null) return;
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(key);
    }
    notifyListeners();
  }

  void removeItem(
    String productId, {
    dynamic selectedSize,
    String? selectedColor,
  }) {
    if (_items.containsKey(productId)) {
      _items.remove(productId);
    } else if (selectedSize != null || selectedColor != null) {
      _items.remove(_key(productId, selectedSize, selectedColor));
    } else {
      _items.removeWhere((_, item) => item.product.id == productId);
    }
    notifyListeners();
  }

  List<CartItem> getItemsForProduct(String productId) =>
      _items.values.where((item) => item.product.id == productId).toList();
  bool hasSizeInCart(String productId, String size) => _items.values.any(
    (item) => item.product.id == productId && item.selectedSize == size,
  );
  int getQuantityForSize(String productId, String size) => _items.values
      .where(
        (item) => item.product.id == productId && item.selectedSize == size,
      )
      .fold(0, (sum, item) => sum + item.quantity);
  void clearCart() {
    _items.clear();
    _restaurantOrderNote = '';
    notifyListeners();
  }
}
