import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CustomerLocation {
  final double latitude;
  final double longitude;

  const CustomerLocation({required this.latitude, required this.longitude});
}

class CustomerLocationService {
  Future<CustomerLocation?> getSavedCustomerLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUser = prefs.getString('user');
    if (cachedUser == null || cachedUser.isEmpty) return null;

    try {
      final decoded = jsonDecode(cachedUser);
      if (decoded is! Map<String, dynamic>) return null;

      final addresses = decoded['deliveryAddresses'];
      if (addresses is! List || addresses.isEmpty) return null;

      Map<String, dynamic>? selected;
      for (final address in addresses) {
        if (address is Map && address['isDefault'] == true) {
          selected = Map<String, dynamic>.from(address);
          break;
        }
      }

      if (selected == null) {
        for (final address in addresses) {
          if (address is Map) {
            selected = Map<String, dynamic>.from(address);
            break;
          }
        }
      }

      if (selected == null) return null;

      final latitude = _parseCoordinate(selected['latitude']);
      final longitude = _parseCoordinate(selected['longitude']);
      if (latitude == null || longitude == null) return null;

      return CustomerLocation(latitude: latitude, longitude: longitude);
    } catch (_) {
      return null;
    }
  }

  double? _parseCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
