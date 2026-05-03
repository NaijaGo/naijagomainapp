// lib/models/product.dart
import 'dart:math' as math;

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final int stockQuantity;
  final String vendorId;
  final String? vendorBusinessName;
  final String? vendorLocationAddress;
  final double? vendorLatitude;
  final double? vendorLongitude;
  final List<Map<String, dynamic>> vendorOperatingHours;
  final bool vendorTemporarilyClosed;
  final String? vendorClosureReason;
  final double deliveryRadiusKm;
  final int prepTimeMinutes;
  final String? restaurantName;
  final String? foodInformation;
  final String? orderStartTime;
  final String? orderEndTime;
  final String? medicineAccess;
  final bool requiresPrescription;
  final bool requiresPharmacistApproval;
  final bool isOverTheCounter;
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
    this.vendorLocationAddress,
    this.vendorLatitude,
    this.vendorLongitude,
    this.vendorOperatingHours = const [],
    this.vendorTemporarilyClosed = false,
    this.vendorClosureReason,
    this.deliveryRadiusKm = 15,
    this.prepTimeMinutes = 30,
    this.restaurantName,
    this.foodInformation,
    this.orderStartTime,
    this.orderEndTime,
    this.medicineAccess,
    this.requiresPrescription = false,
    this.requiresPharmacistApproval = false,
    this.isOverTheCounter = false,
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
          (json['imageUrls'] as List<dynamic>).map((url) => url.toString()),
        );
      } else if (json['imageUrls'] is String) {
        parsedImageUrls = [json['imageUrls']];
      }
    } catch (e) {
      parsedImageUrls = [];
    }

    String vendorId;
    String? vendorBusinessName;
    String? vendorLocationAddress;
    double? vendorLatitude;
    double? vendorLongitude;
    List<Map<String, dynamic>> vendorOperatingHours = const [];
    bool vendorTemporarilyClosed = false;
    String? vendorClosureReason;
    double deliveryRadiusKm = 15;
    int prepTimeMinutes = 30;

    final productLocation = json['productLocation'] is Map
        ? Map<String, dynamic>.from(json['productLocation'] as Map)
        : json['pickupLocation'] is Map
        ? Map<String, dynamic>.from(json['pickupLocation'] as Map)
        : <String, dynamic>{};

    final productLocationAddress =
        productLocation['formattedAddress']?.toString() ??
        productLocation['address']?.toString() ??
        productLocation['addressLine']?.toString();
    final productLatitude = _parseDouble(productLocation['latitude']);
    final productLongitude = _parseDouble(productLocation['longitude']);

    if (json['vendor'] is Map) {
      final vendor = Map<String, dynamic>.from(json['vendor'] as Map);
      vendorId = vendor['_id'] ?? '';
      vendorBusinessName = vendor['businessName'];
      vendorOperatingHours = (vendor['operatingHours'] as List? ?? [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      vendorTemporarilyClosed = vendor['isTemporarilyClosed'] == true;
      vendorClosureReason = vendor['temporaryClosureReason']?.toString();
      deliveryRadiusKm =
          _parseDouble(vendor['deliveryRadiusKm']) ?? deliveryRadiusKm;
      prepTimeMinutes =
          int.tryParse(vendor['prepTimeMinutes']?.toString() ?? '') ??
          prepTimeMinutes;
      final vendorLocation = vendor['businessLocation'] is Map
          ? Map<String, dynamic>.from(vendor['businessLocation'] as Map)
          : vendor['location'] is Map
          ? Map<String, dynamic>.from(vendor['location'] as Map)
          : <String, dynamic>{};
      vendorLocationAddress =
          vendorLocation['formattedAddress']?.toString() ??
          vendorLocation['address']?.toString() ??
          vendorLocation['addressLine']?.toString();
      vendorLatitude = _parseDouble(vendorLocation['latitude']);
      vendorLongitude = _parseDouble(vendorLocation['longitude']);
    } else {
      vendorId = json['vendor'] ?? '';
      vendorBusinessName = null;
    }

    final productVendorLocation = json['vendorLocation'] is Map
        ? Map<String, dynamic>.from(json['vendorLocation'] as Map)
        : json['businessLocation'] is Map
        ? Map<String, dynamic>.from(json['businessLocation'] as Map)
        : <String, dynamic>{};

    vendorLocationAddress ??=
        productVendorLocation['formattedAddress']?.toString() ??
        productVendorLocation['address']?.toString() ??
        productVendorLocation['addressLine']?.toString();
    vendorLatitude ??= _parseDouble(productVendorLocation['latitude']);
    vendorLongitude ??= _parseDouble(productVendorLocation['longitude']);

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
        parsedAvailableSizes = availableList
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
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
      vendorLocationAddress: productLocationAddress ?? vendorLocationAddress,
      vendorLatitude: productLatitude ?? vendorLatitude,
      vendorLongitude: productLongitude ?? vendorLongitude,
      vendorOperatingHours: vendorOperatingHours,
      vendorTemporarilyClosed: vendorTemporarilyClosed,
      vendorClosureReason: vendorClosureReason,
      deliveryRadiusKm: deliveryRadiusKm,
      prepTimeMinutes: prepTimeMinutes,
      restaurantName:
          json['restaurantName']?.toString() ??
          json['restaurant']?.toString() ??
          json['foodVendorName']?.toString(),
      foodInformation:
          json['foodInformation']?.toString() ??
          json['foodInfo']?.toString() ??
          json['ingredients']?.toString(),
      orderStartTime:
          json['orderStartTime']?.toString() ??
          json['availableFrom']?.toString() ??
          json['restaurantOpenTime']?.toString(),
      orderEndTime:
          json['orderEndTime']?.toString() ??
          json['availableUntil']?.toString() ??
          json['restaurantCloseTime']?.toString(),
      medicineAccess:
          json['medicineAccess']?.toString() ??
          json['medicineType']?.toString() ??
          json['drugType']?.toString() ??
          json['accessType']?.toString(),
      requiresPrescription: json['requiresPrescription'] == true,
      requiresPharmacistApproval:
          json['requiresPharmacistApproval'] == true ||
          json['requiresPharmacistConsultation'] == true,
      isOverTheCounter:
          json['isOverTheCounter'] == true || json['isOTC'] == true,
      imageUrls: parsedImageUrls,
      salesCount: json['salesCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      isFlashsale: json['is_flashsale'] ?? false,
      sizeData: parsedSizeData,
      availableSizes: parsedAvailableSizes,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'description': description,
    'price': price,
    'category': category,
    'stockQuantity': stockQuantity,
    'vendor': vendorId,
    'vendorLocation': {
      'formattedAddress': vendorLocationAddress,
      'latitude': vendorLatitude,
      'longitude': vendorLongitude,
    },
    'productLocation': {
      'formattedAddress': vendorLocationAddress,
      'latitude': vendorLatitude,
      'longitude': vendorLongitude,
    },
    'operatingHours': vendorOperatingHours,
    'isTemporarilyClosed': vendorTemporarilyClosed,
    'temporaryClosureReason': vendorClosureReason,
    'deliveryRadiusKm': deliveryRadiusKm,
    'prepTimeMinutes': prepTimeMinutes,
    'restaurantName': restaurantName,
    'foodInformation': foodInformation,
    'orderStartTime': orderStartTime,
    'orderEndTime': orderEndTime,
    'medicineAccess': medicineAccess,
    'requiresPrescription': requiresPrescription,
    'requiresPharmacistApproval': requiresPharmacistApproval,
    'isOverTheCounter': isOverTheCounter,
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

  bool get isRestaurantItem {
    final normalized = category.toLowerCase();
    if (normalized.contains('restaurant equipment')) return false;
    return normalized == 'restaurant' ||
        normalized.startsWith('restaurant >') ||
        normalized.contains('meal') ||
        normalized.contains('fast food') ||
        normalized.contains('local dishes') ||
        normalized.contains('pastries') ||
        normalized.contains('drinks') ||
        normalized.contains('catering');
  }

  String get displayRestaurantName {
    final name = restaurantName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final vendorName = vendorBusinessName?.trim();
    if (vendorName != null && vendorName.isNotEmpty) return vendorName;

    return 'Restaurant unavailable';
  }

  String get displayRestaurantLocation {
    final location = vendorLocationAddress?.trim();
    if (location != null && location.isNotEmpty) return location;
    return 'Location unavailable';
  }

  String get displayVendorLocation {
    final location = vendorLocationAddress?.trim();
    if (location != null && location.isNotEmpty) return location;
    return 'Location unavailable';
  }

  bool get hasVendorCoordinates =>
      vendorLatitude != null && vendorLongitude != null;

  bool get shouldShowVendorLocation => isRestaurantItem || isMedicine;

  double? distanceKmFrom(double? latitude, double? longitude) {
    if (latitude == null || longitude == null || !hasVendorCoordinates) {
      return null;
    }

    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(vendorLatitude! - latitude);
    final dLon = _degreesToRadians(vendorLongitude! - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(latitude)) *
            math.cos(_degreesToRadians(vendorLatitude!)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  int? estimatedMinutesFrom(double? latitude, double? longitude) {
    final distance = distanceKmFrom(latitude, longitude);
    if (distance == null) return null;

    const averageCitySpeedKmPerHour = 24.0;
    final travelMinutes = (distance / averageCitySpeedKmPerHour * 60).ceil();
    final minutes = isRestaurantItem ? travelMinutes + prepTimeMinutes : travelMinutes;
    return minutes < 1 ? 1 : minutes;
  }

  String? distanceAndMinutesLabel(double? latitude, double? longitude) {
    final distance = distanceKmFrom(latitude, longitude);
    final minutes = estimatedMinutesFrom(latitude, longitude);
    if (distance == null || minutes == null) return null;

    final distanceLabel = distance < 1
        ? '${(distance * 1000).round()} m'
        : '${distance.toStringAsFixed(distance < 10 ? 1 : 0)} km';
    return '$distanceLabel • about $minutes min away';
  }

  bool isOutsideDeliveryRadius(double? latitude, double? longitude) {
    final distance = distanceKmFrom(latitude, longitude);
    if (distance == null || deliveryRadiusKm <= 0) return false;
    return distance > deliveryRadiusKm;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  String get displayFoodInformation {
    final info = foodInformation?.trim();
    if (info != null && info.isNotEmpty) return info;

    final details = description.trim();
    if (details.isNotEmpty &&
        details.toLowerCase() != name.trim().toLowerCase()) {
      return details;
    }

    return category;
  }

  String get displayOrderWindow {
    if (!isRestaurantItem) return '';
    return '${_formatTimeLabel(normalizedOrderStartTime)} - ${_formatTimeLabel(normalizedOrderEndTime)}';
  }

  String get restaurantOpenStatusLabel {
    if (!isRestaurantItem) return '';
    if (vendorTemporarilyClosed) {
      final reason = vendorClosureReason?.trim();
      return reason == null || reason.isEmpty ? 'Closed today' : 'Closed: $reason';
    }
    if (isWithinRestaurantOrderWindow) return 'Open now';
    return 'Opens at ${_formatTimeLabel(effectiveOpeningTime)}';
  }

  String get storeHoursLabel {
    if (!isRestaurantItem) return '';
    final hours = _todayVendorHours;
    if (hours == null) return 'Store $displayOrderWindow';
    if (hours['isOpen'] == false) return 'Store closed today';
    final open = _normalizeTimeValue(hours['openTime']?.toString()) ?? '09:00';
    final close =
        _normalizeTimeValue(hours['closeTime']?.toString()) ?? '19:00';
    final last =
        _normalizeTimeValue(hours['lastOrderTime']?.toString()) ?? close;
    return 'Store ${_formatTimeLabel(open)} - ${_formatTimeLabel(close)} • last order ${_formatTimeLabel(last)}';
  }

  String get prepTimeLabel =>
      prepTimeMinutes <= 0 ? 'Ready soon' : 'Prep about $prepTimeMinutes min';

  String get effectiveOpeningTime {
    final hours = _todayVendorHours;
    if (hours != null && hours['isOpen'] != false) {
      return _normalizeTimeValue(hours['openTime']?.toString()) ??
          normalizedOrderStartTime;
    }
    return normalizedOrderStartTime;
  }

  String get normalizedOrderStartTime =>
      _normalizeTimeValue(orderStartTime) ?? '09:00';

  String get normalizedOrderEndTime =>
      _normalizeTimeValue(orderEndTime) ?? '19:00';

  bool get isWithinRestaurantOrderWindow {
    if (!isRestaurantItem) return true;
    if (vendorTemporarilyClosed) return false;

    final hours = _todayVendorHours;
    if (hours != null) {
      if (hours['isOpen'] == false) return false;
      final open = _minutesFromTime(
        _normalizeTimeValue(hours['openTime']?.toString()) ?? '09:00',
      );
      final last = _minutesFromTime(
        _normalizeTimeValue(hours['lastOrderTime']?.toString()) ??
            _normalizeTimeValue(hours['closeTime']?.toString()) ??
            '19:00',
      );
      final now = DateTime.now();
      final current = now.hour * 60 + now.minute;
      if (!_isCurrentWithin(open, last, current)) return false;
    }

    final now = DateTime.now();
    final start = _minutesFromTime(normalizedOrderStartTime);
    final end = _minutesFromTime(normalizedOrderEndTime);
    final current = now.hour * 60 + now.minute;

    return _isCurrentWithin(start, end, current);
  }

  Map<String, dynamic>? get _todayVendorHours {
    if (vendorOperatingHours.isEmpty) return null;
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final today = days[DateTime.now().weekday - 1];
    for (final entry in vendorOperatingHours) {
      if (entry['day']?.toString().toLowerCase() == today) return entry;
    }
    return null;
  }

  static bool _isCurrentWithin(int start, int end, int current) {
    if (start == end) return true;
    if (start < end) return current >= start && current <= end;
    return current >= start || current <= end;
  }

  static String? _normalizeTimeValue(String? rawValue) {
    final raw = rawValue?.trim();
    if (raw == null || raw.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static int _minutesFromTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  static String _formatTimeLabel(String value) {
    final parts = value.split(':');
    final hour24 = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  bool get isMedicine {
    final normalized = category.toLowerCase();
    return normalized.contains('medicine') ||
        normalized.contains('pharmacy') ||
        normalized.contains('drug');
  }

  bool get isRestrictedMedicine {
    if (!isMedicine) return false;
    if (isOverTheCounter) return false;

    final access = medicineAccess?.toLowerCase().trim() ?? '';
    final restrictedByAccess =
        access.contains('prescription') ||
        access.contains('pharmacist') ||
        access.contains('restricted') ||
        access.contains('controlled');

    return requiresPrescription ||
        requiresPharmacistApproval ||
        restrictedByAccess;
  }

  bool get canBuyDirectly => !isRestrictedMedicine;

  String get medicineAccessLabel {
    if (!isMedicine) return '';
    return isRestrictedMedicine ? 'Consult pharmacist' : 'Over the counter';
  }
}
