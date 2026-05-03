import 'package:naija_go/models/address.dart';

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String alternatePhoneNumber;
  final bool isEmailVerified;
  final bool isDeviceVerified;
  final String? deviceFingerprint;
  final String? profilePicUrl;
  final bool isAdmin;

  // Vendor-specific fields
  final bool isVendor;
  final String vendorStatus;
  final DateTime? vendorRequestDate;
  final DateTime? vendorRejectionDate;
  final String? businessName;
  final List<String> businessCategories;
  final String? businessLogoUrl;
  final String? businessWhatsAppNumber;
  final String? businessSupportPhone;
  final double deliveryRadiusKm;
  final int prepTimeMinutes;
  final bool isTemporarilyClosed;
  final int totalProducts;
  final int productsSold;
  final int productsUnsold;
  final int followersCount;
  final double vendorWalletBalance;
  final double appWalletBalance;

  // Buyer-specific fields
  final double userWalletBalance;
  final List<String> savedItems;
  final List<Address> deliveryAddresses;

  // Common fields
  final List<dynamic> notifications;
  final Map<String, bool> notificationPreferences;
  final DateTime createdAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.alternatePhoneNumber = '',
    required this.isEmailVerified,
    required this.isDeviceVerified,
    this.deviceFingerprint,
    this.profilePicUrl,
    required this.isAdmin,
    required this.isVendor,
    required this.vendorStatus,
    this.vendorRequestDate,
    this.vendorRejectionDate,
    this.businessName,
    this.businessCategories = const [],
    this.businessLogoUrl,
    this.businessWhatsAppNumber,
    this.businessSupportPhone,
    this.deliveryRadiusKm = 15,
    this.prepTimeMinutes = 30,
    this.isTemporarilyClosed = false,
    required this.totalProducts,
    required this.productsSold,
    required this.productsUnsold,
    required this.followersCount,
    required this.vendorWalletBalance,
    required this.appWalletBalance,
    required this.userWalletBalance,
    this.savedItems = const [],
    this.deliveryAddresses = const [],
    this.notifications = const [],
    this.notificationPreferences = const {
      'orderUpdates': true,
      'appOrderAlerts': true,
      'whatsappOrderAlerts': true,
      'promotions': true,
      'priceAlerts': true,
    },
    required this.createdAt,
  });

  static String extractId(dynamic idField) {
    if (idField is Map && idField.containsKey('\$oid')) {
      return idField['\$oid'] as String;
    } else if (idField is String) {
      return idField;
    }
    return '';
  }

  static DateTime? parseDate(dynamic dateField) {
    if (dateField is Map && dateField.containsKey('\$date')) {
      return DateTime.tryParse(dateField['\$date']);
    } else if (dateField is String) {
      return DateTime.tryParse(dateField);
    }
    return null;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final rawNotificationPreferences =
        json['notificationPreferences'] as Map<String, dynamic>?;

    return User(
      id: extractId(json['_id'] ?? json['id']),
      firstName: (json['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phoneNumber: (json['phoneNumber'] ?? '') as String,
      alternatePhoneNumber: (json['alternatePhoneNumber'] ?? '') as String,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      isDeviceVerified: json['isDeviceVerified'] as bool? ?? false,
      deviceFingerprint: json['deviceFingerprint'] as String?,
      profilePicUrl: json['profilePicUrl'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
      isVendor: json['isVendor'] as bool? ?? false,
      vendorStatus: (json['vendorStatus'] ?? 'none') as String,
      vendorRequestDate: parseDate(json['vendorRequestDate']),
      vendorRejectionDate: parseDate(json['vendorRejectionDate']),
      businessName: json['businessName'] as String?,
      businessCategories: (json['businessCategories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      businessLogoUrl: json['businessLogoUrl'] as String?,
      businessWhatsAppNumber: json['businessWhatsAppNumber'] as String?,
      businessSupportPhone: json['businessSupportPhone'] as String?,
      deliveryRadiusKm:
          (json['deliveryRadiusKm'] as num?)?.toDouble() ?? 15.0,
      prepTimeMinutes: json['prepTimeMinutes'] as int? ?? 30,
      isTemporarilyClosed: json['isTemporarilyClosed'] as bool? ?? false,
      totalProducts: json['totalProducts'] as int? ?? 0,
      productsSold: json['productsSold'] as int? ?? 0,
      productsUnsold: json['productsUnsold'] as int? ?? 0,
      followersCount: json['followersCount'] as int? ?? 0,
      vendorWalletBalance:
          (json['vendorWalletBalance'] as num?)?.toDouble() ?? 0.0,
      appWalletBalance: (json['appWalletBalance'] as num?)?.toDouble() ?? 0.0,
      userWalletBalance: (json['userWalletBalance'] as num?)?.toDouble() ?? 0.0,
      savedItems: (json['savedItems'] as List?)
              ?.map(extractId)
              .toList() ??
          [],
      deliveryAddresses: (json['deliveryAddresses'] as List?)
              ?.map((addrJson) =>
                  Address.fromJson(addrJson as Map<String, dynamic>))
              .toList() ??
          [],
      notifications: json['notifications'] as List? ?? [],
      notificationPreferences: {
        'orderUpdates':
            rawNotificationPreferences?['orderUpdates'] as bool? ?? true,
        'appOrderAlerts':
            rawNotificationPreferences?['appOrderAlerts'] as bool? ?? true,
        'whatsappOrderAlerts':
            rawNotificationPreferences?['whatsappOrderAlerts'] as bool? ??
                true,
        'promotions':
            rawNotificationPreferences?['promotions'] as bool? ?? true,
        'priceAlerts':
            rawNotificationPreferences?['priceAlerts'] as bool? ?? true,
      },
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'alternatePhoneNumber': alternatePhoneNumber,
      'isEmailVerified': isEmailVerified,
      'isDeviceVerified': isDeviceVerified,
      'deviceFingerprint': deviceFingerprint,
      'profilePicUrl': profilePicUrl,
      'isAdmin': isAdmin,
      'isVendor': isVendor,
      'vendorStatus': vendorStatus,
      'vendorRequestDate': vendorRequestDate?.toIso8601String(),
      'vendorRejectionDate': vendorRejectionDate?.toIso8601String(),
      'businessName': businessName,
      'businessCategories': businessCategories,
      'businessLogoUrl': businessLogoUrl,
      'businessWhatsAppNumber': businessWhatsAppNumber,
      'businessSupportPhone': businessSupportPhone,
      'deliveryRadiusKm': deliveryRadiusKm,
      'prepTimeMinutes': prepTimeMinutes,
      'isTemporarilyClosed': isTemporarilyClosed,
      'totalProducts': totalProducts,
      'productsSold': productsSold,
      'productsUnsold': productsUnsold,
      'followersCount': followersCount,
      'vendorWalletBalance': vendorWalletBalance,
      'appWalletBalance': appWalletBalance,
      'userWalletBalance': userWalletBalance,
      'savedItems': savedItems,
      'deliveryAddresses': deliveryAddresses.map((e) => e.toJson()).toList(),
      'notifications': notifications,
      'notificationPreferences': notificationPreferences,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
