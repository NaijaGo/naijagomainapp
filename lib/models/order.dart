// lib/models/order_model.dart

import 'address.dart';
import 'order_item.dart'; // <-- Now imported and used

// This represents the structure of an Order sent to and received from the API.
class Order {
  final String id;
  final String userId; // Maps to 'user' in Mongoose schema
  final List<OrderItem> orderItems; // Now strongly typed as List<OrderItem>
  final Address shippingAddress; // MUST be the Address object, not a String

  // Price Details (Required by Mongoose Order.js)
  final double taxPrice;
  final double shippingPrice;
  final double totalPrice;
  final double? deliveryDistanceKm;
  final double? serviceFee;

  // Payment Status
  final String paymentMethod;
  final bool isPaid;
  final DateTime? paidAt;
  final String status; // Maps to 'orderStatus' in Mongoose schema

  // Payment Gateway Results (used for API submission)
  final String paymentReference;
  
  // NEW: Fields to hold the vendor's location, which must be fetched
  final double? vendorLatitude;
  final double? vendorLongitude;


  Order({
    this.id = '',
    required this.userId,
    required this.orderItems,
    required this.shippingAddress,
    required this.totalPrice,
    this.taxPrice = 0.0,
    this.shippingPrice = 0.0,
    this.serviceFee = 0.0,
    this.deliveryDistanceKm,
    this.paymentMethod = 'Card',
    this.isPaid = false,
    this.paidAt,
    // ⬇️ FIX: Updated default status from 'pending' to 'pending_payment'
    this.status = 'pending_payment', 
    this.paymentReference = '',
    // Initialize new vendor location fields
    this.vendorLatitude,
    this.vendorLongitude,
  });

  // --- FACTORY CONSTRUCTOR FOR API RESPONSE (RETRIEVING AN ORDER) ---
  factory Order.fromJson(Map<String, dynamic> json) {
    // Note: Mongoose sends the Address details as a flat object
    // We safely parse it into an Address model.
    final addressJson = json['shippingAddress'] as Map<String, dynamic>?;

    // --- FIX: Map the dynamic list of order items to OrderItem objects ---
    final List<OrderItem> items = (json['orderItems'] as List<dynamic>? ?? [])
        .map((itemJson) => OrderItem.fromJson(itemJson as Map<String, dynamic>))
        .toList();

    return Order(
      id: json['_id'] ?? '',
      userId: json['user'] ?? '',
      orderItems: items, // Using the correctly parsed list
      
      // We must reconstruct the full Address object from the response
      shippingAddress: addressJson != null
          ? Address.fromJson({
              'address': addressJson['address'],
              'city': addressJson['city'],
              'postalCode': addressJson['postalCode'],
              'country': addressJson['country'],
              // When retrieving, we also grab coordinates from 'userLocation' if available
              'latitude': json['userLocation']?['latitude'],
              'longitude': json['userLocation']?['longitude'],
            })
          : Address(name: 'Unknown', phoneNumber: 'Unknown', addressLine: 'N/A'),

      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      taxPrice: (json['taxPrice'] as num?)?.toDouble() ?? 0.0,
      shippingPrice: (json['shippingPrice'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0.0,
      deliveryDistanceKm: (json['deliveryDistanceKm'] as num?)?.toDouble(),

      paymentMethod: json['paymentMethod'] ?? 'Card',
      isPaid: json['isPaid'] ?? false,
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      
      // ⬇️ THE CRITICAL FIX ⬇️
      status: json['mainOrderStatus'] ?? 'pending_payment', // Changed from 'orderStatus' to 'mainOrderStatus'
      
      // Use paymentResult ID for reference
      paymentReference: json['paymentResult']?['id'] ?? '',
      
      // When retrieving, we populate vendor location from the API response's vendorLocation field
      vendorLatitude: json['vendorLocation']?['latitude'] != null ? (json['vendorLocation']?['latitude'] as num).toDouble() : null,
      vendorLongitude: json['vendorLocation']?['longitude'] != null ? (json['vendorLocation']?['longitude'] as num).toDouble() : null,
    );
  }

  // --- METHOD FOR API SUBMISSION (POSTING A NEW ORDER) ---
  /// Method to prepare the order data for API submission (POST to /orders).
  /// This structure matches the required fields in models/Order.js.
  Map<String, dynamic> toApiJson() {
    // 1. Core Address (only the fields Mongoose expects for 'shippingAddress')
    final shippingDetails = {
      'address': shippingAddress.addressLine, // Mongoose expects 'address'
      'city': shippingAddress.city,
      'postalCode': shippingAddress.zipCode, // Mongoose expects 'postalCode'
      'country': shippingAddress.country,
    };

    // 2. Location Coordinates (Mongoose expects this separately in 'userLocation')
    final userLocationDetails = {
      'latitude': shippingAddress.latitude,
      'longitude': shippingAddress.longitude,
    };

    // 3. Vendor Location (Now uses the fields passed to the model)
    final vendorLocationDetails = {
      // Replaced hardcoded values with dynamic fields. If null, it sends null/0.0 which Mongoose may error on.
      // Make sure the calling code passes non-null values for these.
      'latitude': vendorLatitude, 
      'longitude': vendorLongitude,
    };


    return {
      'user': userId, // Mongoose field name is 'user'
      'totalPrice': totalPrice,
      'taxPrice': taxPrice,
      'shippingPrice': shippingPrice,
      'serviceFee': serviceFee,
      'deliveryDistanceKm': deliveryDistanceKm,
      
      // Map to the backend-friendly format using OrderItem.toApiJson()
      'orderItems': orderItems.map((item) => item.toApiJson()).toList(),
      
      'shippingAddress': shippingDetails,
      'userLocation': userLocationDetails,
      'vendorLocation': vendorLocationDetails, // Now dynamic
      'paymentMethod': paymentMethod, 
      'orderStatus': status, 
      'paymentResult': {
        'id': paymentReference,
        'status': isPaid ? 'successful' : 'pending',
        'update_time': DateTime.now().toIso8601String(),
        // This remains conditional based on paymentMethod
        'payment_type': paymentMethod == 'Wallet' ? 'Wallet' : 'Flutterwave', 
      },
      'isPaid': isPaid,
    };
  }
}
