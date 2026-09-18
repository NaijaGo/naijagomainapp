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
  static const Duration _cacheTtl = Duration(minutes: 5);
  static final Map<String, _CachedAddressSearch> _cache = {};

  String _normalize(String value) => value.trim().toLowerCase();

  List<AddressSuggestion> cachedSuggestions(String query) {
    final normalized = _normalize(query);
    if (normalized.length < 2) return const [];
    final now = DateTime.now();
    _cache.removeWhere(
      (_, value) => now.difference(value.createdAt) > _cacheTtl,
    );

    final exact = _cache[normalized];
    if (exact != null) return exact.suggestions;

    final words = normalized.split(RegExp(r'\s+'));
    final seen = <String>{};
    final matches = <AddressSuggestion>[];
    for (final entry in _cache.entries) {
      if (!normalized.startsWith(entry.key) &&
          !entry.key.startsWith(normalized)) {
        continue;
      }
      for (final suggestion in entry.value.suggestions) {
        final searchable = suggestion.label.toLowerCase();
        if (words.every(searchable.contains) && seen.add(suggestion.id)) {
          matches.add(suggestion);
        }
      }
    }
    return matches.take(15).toList(growable: false);
  }

  Future<List<AddressSuggestion>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final normalized = _normalize(query);
    final cached = _cache[normalized];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <= _cacheTtl) {
      return cached.suggestions;
    }

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
    final suggestions = items
        .whereType<Map<String, dynamic>>()
        .map(AddressSuggestion.fromJson)
        .toList();
    _cache[normalized] = _CachedAddressSearch(DateTime.now(), suggestions);
    if (_cache.length > 50) {
      final oldest = _cache.entries.reduce(
        (a, b) => a.value.createdAt.isBefore(b.value.createdAt) ? a : b,
      );
      _cache.remove(oldest.key);
    }
    return suggestions;
  }
}

class _CachedAddressSearch {
  final DateTime createdAt;
  final List<AddressSuggestion> suggestions;

  const _CachedAddressSearch(this.createdAt, this.suggestions);
}
