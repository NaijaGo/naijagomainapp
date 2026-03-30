import 'package:flutter/material.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;
  final dynamic selectedSize;

  CartItem({
    required this.product, 
    this.quantity = 1,
    this.selectedSize,
  });

  Map<String, dynamic> toJson() {

     debugPrint('CartItem.toJson() - selectedSize type: ${selectedSize.runtimeType}');
      debugPrint('CartItem.toJson() - selectedSize value: $selectedSize');

    return {
      'product': product.id,
      'name': product.name,
      'image': product.imageUrls.isNotEmpty
          ? product.imageUrls[0]
          : 'https://placehold.co/100x100/CCCCCC/000000?text=No+Image',
      'quantity': quantity,
      'price': product.price,
      'vendor': product.vendorId,
      'selectedSize': selectedSize,
    };
  }

  String get displayName {
    if (selectedSize != null) {
      if (selectedSize is String) {
        return '${product.name} ($selectedSize)';
      } else if (selectedSize is Map<String, dynamic>) {
        final sizeMap = selectedSize as Map<String, dynamic>;
        final dynamic labelDynamic = sizeMap['label'];
        final String label = labelDynamic?.toString() ?? '';
        if (label.isNotEmpty) {
          return '${product.name} ($label)';
        }
        return product.name;
      }
    }
    return product.name;
  }
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    return _items.values.fold(0.0,
        (sum, item) => sum + (item.product.price * item.quantity));
  }

  void addProduct(Product product, {dynamic selectedSize}) {
    String itemKey = product.id;
    
    if (product.hasSizes && selectedSize != null) {
      String sizeString;
      if (selectedSize is String) {
        sizeString = selectedSize;
      } else if (selectedSize is Map<String, dynamic>) {
        final sizeMap = selectedSize;
        final dynamic labelDynamic = sizeMap['label'];
        sizeString = labelDynamic?.toString() ?? 'custom';
      } else {
        sizeString = selectedSize.toString();
      }
      itemKey = '${product.id}_$sizeString';
    }
    
    if (_items.containsKey(itemKey)) {
      _items.update(itemKey, (existingItem) {
        if (existingItem.quantity < product.stockQuantity) {
          existingItem.quantity++;
        } else {
          debugPrint('Cannot add more. Max stock reached for ${product.name}');
        }
        return existingItem;
      });
    } else {
      if (product.stockQuantity > 0) {
        _items.putIfAbsent(
          itemKey,
          () => CartItem(
            product: product,
            quantity: 1,
            selectedSize: selectedSize,
          ),
        );
      } else {
        debugPrint('Product ${product.name} is out of stock.');
      }
    }
    notifyListeners();
  }

  void removeSingleItem(String productId, {dynamic selectedSize}) {
    String itemKey = productId;
    if (selectedSize != null) {
      String sizeString;
      if (selectedSize is String) {
        sizeString = selectedSize;
      } else if (selectedSize is Map<String, dynamic>) {
        final sizeMap = selectedSize;
        final dynamic labelDynamic = sizeMap['label'];
        sizeString = labelDynamic?.toString() ?? 'custom';
      } else {
        sizeString = selectedSize.toString();
      }
      itemKey = '${productId}_$sizeString';
    }
    
    if (!_items.containsKey(itemKey)) {
      final existingKey = _items.keys.firstWhere(
        (key) => key.startsWith(productId),
        orElse: () => '',
      );
      
      if (existingKey.isEmpty) return;
      itemKey = existingKey;
    }
    
    if (_items[itemKey]!.quantity > 1) {
      _items.update(
        itemKey,
        (existingItem) => CartItem(
          product: existingItem.product,
          quantity: existingItem.quantity - 1,
          selectedSize: existingItem.selectedSize,
        ),
      );
    } else {
      _items.remove(itemKey);
    }
    notifyListeners();
  }

  void removeItem(String productId, {dynamic selectedSize}) {
    String itemKey = productId;
    if (selectedSize != null) {
      String sizeString;
      if (selectedSize is String) {
        sizeString = selectedSize;
      } else if (selectedSize is Map<String, dynamic>) {
        final sizeMap = selectedSize;
        final dynamic labelDynamic = sizeMap['label'];
        sizeString = labelDynamic?.toString() ?? 'custom';
      } else {
        sizeString = selectedSize.toString();
      }
      itemKey = '${productId}_$sizeString';
    }
    
    if (!_items.containsKey(itemKey)) {
      final keysToRemove = _items.keys
          .where((key) => key.startsWith(productId))
          .toList();
      
      for (final key in keysToRemove) {
        _items.remove(key);
      }
    } else {
      _items.remove(itemKey);
    }
    notifyListeners();
  }

  List<CartItem> getItemsForProduct(String productId) {
    return _items.values
        .where((item) => item.product.id == productId)
        .toList();
  }

  bool hasSizeInCart(String productId, String size) {
    final key = '${productId}_$size';
    return _items.containsKey(key);
  }

  int getQuantityForSize(String productId, String size) {
    final key = '${productId}_$size';
    return _items[key]?.quantity ?? 0;
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
