// lib/models/product.dart
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final int stockQuantity;
  final String vendorId;
  final String? vendorBusinessName;
  final List<String> imageUrls;
  final int salesCount;
  final bool isActive;
  final bool isFlashsale;
  final Map<String, dynamic>? sizeData; // NEW
  final List<String> availableSizes; // NEW

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.stockQuantity,
    required this.vendorId,
    this.vendorBusinessName,
    this.imageUrls = const [],
    this.salesCount = 0,
    this.isActive = true,
    this.isFlashsale = false,
    this.sizeData, // NEW
    this.availableSizes = const [], // NEW
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> parsedImageUrls = [];

    try {
      if (json['imageUrls'] is List) {
        parsedImageUrls = List<String>.from(
            (json['imageUrls'] as List<dynamic>).map((url) => url.toString()));
      } else if (json['imageUrls'] is String) {
        parsedImageUrls = [json['imageUrls']];
      }
    } catch (e) {
      parsedImageUrls = [];
    }

    String vendorId;
    String? vendorBusinessName;

    if (json['vendor'] is Map) {
      vendorId = json['vendor']['_id'] ?? '';
      vendorBusinessName = json['vendor']['businessName'];
    } else {
      vendorId = json['vendor'] ?? '';
      vendorBusinessName = null;
    }

    // NEW: Parse size data
    Map<String, dynamic>? parsedSizeData;
    List<String> parsedAvailableSizes = [];
    
    if (json['sizeData'] != null && json['sizeData'] is Map) {
      parsedSizeData = Map<String, dynamic>.from(json['sizeData']);
      
      // Extract available sizes for easy access
      if (parsedSizeData['sizes'] is List) {
        final sizesList = List<dynamic>.from(parsedSizeData['sizes']);
        for (var size in sizesList) {
          if (size is Map) {
            final value = size['value']?.toString();
            if (value != null && value.isNotEmpty) {
              parsedAvailableSizes.add(value);
            }
          } else if (size is String) {
            parsedAvailableSizes.add(size);
          }
        }
      }
      
      // Also check virtual field from backend
      if (json['availableSizes'] is List) {
        final availableList = List<dynamic>.from(json['availableSizes']);
        parsedAvailableSizes = availableList.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
    }

    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(),
      category: json['category'] ?? '',
      stockQuantity: json['stockQuantity'] ?? 0,
      vendorId: vendorId,
      vendorBusinessName: vendorBusinessName,
      imageUrls: parsedImageUrls,
      salesCount: json['salesCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      isFlashsale: json['is_flashsale'] ?? false,
      sizeData: parsedSizeData,
      availableSizes: parsedAvailableSizes,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'stockQuantity': stockQuantity,
        'vendor': vendorId,
        'imageUrls': imageUrls,
        'salesCount': salesCount,
        'isActive': isActive,
        'is_flashsale': isFlashsale,
        'sizeData': sizeData,
      };

  // NEW: Helper method to check if product has sizes
  bool get hasSizes => availableSizes.isNotEmpty;

  // NEW: Get size type for display
  String get sizeType {
    if (sizeData == null || sizeData!['type'] == null) {
      return '';
    }
    final type = sizeData!['type'].toString();
    switch (type) {
      case 'clothing':
        return 'Clothing Size';
      case 'shoes':
        return 'Shoe Size';
      case 'watches':
        return 'Watch Size';
      case 'baby':
        return 'Baby Clothing Size';
      case 'pet':
        return 'Pet Clothing Size';
      case 'custom':
        return 'Custom Dimensions';
      default:
        return 'Size';
    }
  }

  // NEW: Get unit for display
  String get sizeUnit {
    if (sizeData == null || sizeData!['unit'] == null) {
      return '';
    }
    return sizeData!['unit'].toString();
  }

  // NEW: Check if it's custom dimensions
  bool get isCustomDimensions {
    if (sizeData == null || sizeData!['type'] == null) {
      return false;
    }
    return sizeData!['type'] == 'custom';
  }
}
