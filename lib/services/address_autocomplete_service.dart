import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class AddressSuggestion {
  final String id;
  final String label;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final double latitude;
  final double longitude;

  const AddressSuggestion({
    required this.id,
    required this.label,
    required this.address,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      country: json['country'] as String? ?? 'Nigeria',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class AddressAutocompleteService {
  Future<List<AddressSuggestion>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw const FormatException('Please log in again.');
    }

    final parameters = <String, String>{'q': query};
    if (latitude != null && longitude != null) {
      parameters['lat'] = latitude.toString();
      parameters['lng'] = longitude.toString();
    }
    final uri = Uri.parse(
      '$baseUrl/api/locations/autocomplete',
    ).replace(queryParameters: parameters);
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw FormatException(
        decoded['message'] as String? ?? 'Address search is unavailable.',
      );
    }
    final items = decoded['suggestions'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AddressSuggestion.fromJson)
        .toList();
  }
}
