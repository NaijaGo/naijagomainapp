//lib/models/order_item.dart
import 'product.dart';

/// Represents a single product line item within an Order, including
/// the quantity and the price at the time the order was placed.
class OrderItem {
  final Product product;
  final int quantity;
  final double price;

  OrderItem({
    required this.product,
    required this.quantity,
    required this.price,
  });

  /// Factory constructor to create an OrderItem from a JSON map (API response).
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Safely extract price and quantity with null-coalescing
    final int quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final double price = (json['price'] as num?)?.toDouble() ?? 0.0;
    
    // The 'product' field in the order item JSON is expected to be another JSON map
    final productJson = json['product'] as Map<String, dynamic>?;

    if (productJson == null) {
      // Throw a helpful error if product data is missing, rather than crashing silently later
      throw const FormatException("Order item data is missing nested product information.");
    }
    
    // Recursively call the Product.fromJson factory to get the strongly-typed Product object
    final product = Product.fromJson(productJson);

    return OrderItem(
      product: product,
      quantity: quantity,
      price: price,
    );
  }

  /// Converts the OrderItem object back into a simplified map for API submission.
  /// This typically only sends the product ID, quantity, and price.
  Map<String, dynamic> toApiJson() => {
    // When POSTing an order, the backend usually expects the Product ID, not the full object.
    'product': product.id, // Send the ID for backend reference
    'quantity': quantity,
    'price': price,
  };

  // We keep a simple toJson for local use or debugging, but toApiJson is used for order submission
  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
    'price': price,
  };
}
