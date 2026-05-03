import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class ResolvedAddress {
  const ResolvedAddress({
    required this.addressLine,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.formattedAddress,
    required this.placemark,
  });

  final String addressLine;
  final String city;
  final String postalCode;
  final String country;
  final String formattedAddress;
  final Placemark placemark;

  bool get hasPostalCode => postalCode.isNotEmpty;
  bool get hasStreetName =>
      AddressResolutionService._looksLikeStreetAddress(addressLine);
}

class AddressResolutionService {
  static const Duration _reverseGeocodeTimeout = Duration(seconds: 10);
  static const String _geoapifyBaseHost = 'api.geoapify.com';
  static const String _geoapifyPath = '/v1/geocode/reverse';

  static Future<ResolvedAddress> resolveFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    ResolvedAddress? nativeResolvedAddress;

    try {
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(_reverseGeocodeTimeout);

      if (placemarks.isNotEmpty) {
        nativeResolvedAddress = _buildNativeResolvedAddress(placemarks);
      }
    } catch (error) {
      debugPrint('Native reverse geocoding failed: $error');
    }

    final geoapifyAddress = await _fetchGeoapifyAddress(latitude, longitude);
    final resolvedAddress = _mergeResolvedAddresses(
      nativeResolvedAddress,
      geoapifyAddress,
    );

    if (resolvedAddress == null) {
      throw Exception('No address found');
    }

    if (_shouldRequireStrictIosAddress() &&
        (!resolvedAddress.hasStreetName || !resolvedAddress.hasPostalCode)) {
      throw Exception(
        'We could not determine an iPhone address with a street name and postal code. Please try again in a slightly different spot.',
      );
    }

    return resolvedAddress;
  }

  static ResolvedAddress _buildNativeResolvedAddress(
    List<Placemark> placemarks,
  ) {
    final rankedPlacemarks = placemarks.toList()
      ..sort((left, right) {
        return _placemarkScore(right).compareTo(_placemarkScore(left));
      });

    final primary = rankedPlacemarks.first;
    final addressLine = _resolveAddressLine(primary, rankedPlacemarks);
    final city =
        _firstNonEmpty([
          primary.locality,
          primary.subAdministrativeArea,
          primary.administrativeArea,
          ...rankedPlacemarks.map((placemark) => placemark.locality),
          ...rankedPlacemarks.map(
            (placemark) => placemark.subAdministrativeArea,
          ),
          ...rankedPlacemarks.map((placemark) => placemark.administrativeArea),
        ]) ??
        '';
    final postalCode =
        _firstNonEmpty([
          primary.postalCode,
          ...rankedPlacemarks.map((placemark) => placemark.postalCode),
        ]) ??
        '';
    final country =
        _firstNonEmpty([
          primary.country,
          ...rankedPlacemarks.map((placemark) => placemark.country),
          'Nigeria',
        ]) ??
        'Nigeria';

    return ResolvedAddress(
      addressLine: addressLine,
      city: city,
      postalCode: postalCode,
      country: country,
      formattedAddress:
          _joinNonEmpty([
            addressLine,
            city,
            if (postalCode.isNotEmpty) postalCode,
            country,
          ]) ??
          addressLine,
      placemark: primary,
    );
  }

  static Future<_GeoapifyResolvedAddress?> _fetchGeoapifyAddress(
    double latitude,
    double longitude,
  ) async {
    if (!_shouldUseGeoapifyEnrichment()) {
      return null;
    }

    final apiKey = dotenv.env['GEOAPIFY_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint(
        'GEOAPIFY_API_KEY is missing. iOS address enrichment will use Apple geocoding only.',
      );
      return null;
    }

    final uri = Uri.https(_geoapifyBaseHost, _geoapifyPath, {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'lang': 'en',
      'apiKey': apiKey,
    });

    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_reverseGeocodeTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          'Geoapify reverse geocoding failed with status ${response.statusCode}.',
        );
        return null;
      }

      final body = jsonDecode(response.body);
      final properties = _extractGeoapifyProperties(body);
      if (properties == null) {
        return null;
      }

      return _GeoapifyResolvedAddress.fromJson(properties);
    } catch (error) {
      debugPrint('Geoapify reverse geocoding error: $error');
      return null;
    }
  }

  static Map<String, dynamic>? _extractGeoapifyProperties(dynamic body) {
    if (body is! Map<String, dynamic>) {
      return null;
    }

    final results = body['results'];
    if (results is List && results.isNotEmpty && results.first is Map) {
      return Map<String, dynamic>.from(results.first as Map);
    }

    final features = body['features'];
    if (features is List && features.isNotEmpty && features.first is Map) {
      final firstFeature = Map<String, dynamic>.from(features.first as Map);
      final properties = firstFeature['properties'];
      if (properties is Map) {
        return Map<String, dynamic>.from(properties);
      }
    }

    return null;
  }

  static ResolvedAddress? _mergeResolvedAddresses(
    ResolvedAddress? nativeResolvedAddress,
    _GeoapifyResolvedAddress? geoapifyAddress,
  ) {
    if (nativeResolvedAddress == null && geoapifyAddress == null) {
      return null;
    }

    final addressLine =
        _firstNonEmpty([
          if (geoapifyAddress?.shouldPreferAddressLine == true)
            geoapifyAddress?.addressLine,
          nativeResolvedAddress?.addressLine,
          geoapifyAddress?.addressLine,
          geoapifyAddress?.streetOnly,
          'Current Location',
        ]) ??
        'Current Location';
    final city =
        _firstNonEmpty([geoapifyAddress?.city, nativeResolvedAddress?.city]) ??
        '';
    final postalCode =
        _firstNonEmpty([
          geoapifyAddress?.postalCode,
          nativeResolvedAddress?.postalCode,
        ]) ??
        '';
    final country =
        _firstNonEmpty([
          geoapifyAddress?.country,
          nativeResolvedAddress?.country,
          'Nigeria',
        ]) ??
        'Nigeria';
    final formattedAddress =
        _firstNonEmpty([
          geoapifyAddress?.formattedAddress,
          _joinNonEmpty([
            addressLine,
            city,
            if (postalCode.isNotEmpty) postalCode,
            country,
          ]),
          nativeResolvedAddress?.formattedAddress,
        ]) ??
        addressLine;

    return ResolvedAddress(
      addressLine: addressLine,
      city: city,
      postalCode: postalCode,
      country: country,
      formattedAddress: formattedAddress,
      placemark: nativeResolvedAddress?.placemark ?? const Placemark(),
    );
  }

  static int _placemarkScore(Placemark placemark) {
    var score = 0;

    if (_clean(placemark.postalCode) != null) {
      score += 8;
    }
    if (_clean(placemark.subThoroughfare) != null) {
      score += 5;
    }
    if (_clean(placemark.thoroughfare) != null) {
      score += 5;
    }
    if (_clean(placemark.street) != null) {
      score += 4;
    }
    if (_clean(placemark.subLocality) != null) {
      score += 3;
    }
    if (_clean(placemark.locality) != null) {
      score += 3;
    }
    if (_clean(placemark.subAdministrativeArea) != null) {
      score += 2;
    }
    if (_clean(placemark.administrativeArea) != null) {
      score += 1;
    }
    if (_clean(placemark.country) != null) {
      score += 1;
    }

    return score;
  }

  static bool _shouldUseGeoapifyEnrichment() {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool _shouldRequireStrictIosAddress() {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  static String _resolveAddressLine(
    Placemark primary,
    List<Placemark> placemarks,
  ) {
    final resolvedAddress =
        _firstNonEmpty([
          _joinNonEmpty([
            primary.subThoroughfare,
            primary.thoroughfare,
          ], separator: ' '),
          _joinNonEmpty([primary.thoroughfare, primary.subLocality]),
          _clean(primary.street),
          ...placemarks.map(
            (placemark) => _joinNonEmpty([
              placemark.subThoroughfare,
              placemark.thoroughfare,
            ], separator: ' '),
          ),
          ...placemarks.map(
            (placemark) =>
                _joinNonEmpty([placemark.thoroughfare, placemark.subLocality]),
          ),
          ...placemarks.map((placemark) => _clean(placemark.street)),
          ...placemarks.map((placemark) => _clean(placemark.name)),
        ]) ??
        _firstNonEmpty([
          primary.subLocality,
          primary.locality,
          ...placemarks.map((placemark) => placemark.subLocality),
          ...placemarks.map((placemark) => placemark.locality),
          'Current Location',
        ]);

    return resolvedAddress ?? 'Current Location';
  }

  static String? _joinNonEmpty(
    Iterable<String?> values, {
    String separator = ', ',
  }) {
    final parts = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final cleaned = _clean(value);
      if (cleaned == null) {
        continue;
      }

      final normalized = cleaned.toLowerCase();
      if (seen.add(normalized)) {
        parts.add(cleaned);
      }
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(separator);
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final cleaned = _clean(value);
      if (cleaned != null) {
        return cleaned;
      }
    }

    return null;
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  static bool _looksLikeStreetAddress(String value) {
    final cleaned = _clean(value);
    if (cleaned == null) {
      return false;
    }

    final normalized = cleaned.toLowerCase();
    if (normalized == 'current location' || normalized.startsWith('area in ')) {
      return false;
    }

    return normalized.contains(RegExp(r'\d')) ||
        normalized.contains(
          RegExp(
            r'\b(road|rd|street|st|avenue|ave|close|cl|crescent|lane|ln|drive|dr|way|boulevard|blvd|highway|route)\b',
          ),
        );
  }
}

class _GeoapifyResolvedAddress {
  const _GeoapifyResolvedAddress({
    required this.addressLine,
    required this.streetOnly,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.formattedAddress,
    required this.resultType,
    required this.confidence,
  });

  factory _GeoapifyResolvedAddress.fromJson(Map<String, dynamic> json) {
    final houseNumber = AddressResolutionService._clean(
      json['housenumber']?.toString(),
    );
    final street = AddressResolutionService._clean(json['street']?.toString());
    final addressLine1 = AddressResolutionService._clean(
      json['address_line1']?.toString(),
    );
    final derivedStreetLine = AddressResolutionService._joinNonEmpty([
      houseNumber,
      street,
    ], separator: ' ');

    final rank = json['rank'];
    final confidence = rank is Map
        ? (rank['confidence'] as num?)?.toDouble() ?? 0
        : (json['confidence'] as num?)?.toDouble() ?? 0;

    return _GeoapifyResolvedAddress(
      addressLine:
          AddressResolutionService._firstNonEmpty([
            addressLine1,
            derivedStreetLine,
          ]) ??
          '',
      streetOnly: street ?? '',
      city:
          AddressResolutionService._firstNonEmpty([
            json['city']?.toString(),
            json['suburb']?.toString(),
            json['county']?.toString(),
            json['state']?.toString(),
          ]) ??
          '',
      postalCode:
          AddressResolutionService._clean(json['postcode']?.toString()) ?? '',
      country:
          AddressResolutionService._clean(json['country']?.toString()) ??
          'Nigeria',
      formattedAddress:
          AddressResolutionService._clean(json['formatted']?.toString()) ?? '',
      resultType:
          AddressResolutionService._clean(json['result_type']?.toString()) ??
          'unknown',
      confidence: confidence,
    );
  }

  final String addressLine;
  final String streetOnly;
  final String city;
  final String postalCode;
  final String country;
  final String formattedAddress;
  final String resultType;
  final double confidence;

  bool get shouldPreferAddressLine {
    const preciseTypes = {'building', 'street', 'amenity'};
    if (preciseTypes.contains(resultType.toLowerCase()) &&
        addressLine.isNotEmpty) {
      return true;
    }

    return confidence >= 0.75 &&
        addressLine.isNotEmpty &&
        AddressResolutionService._looksLikeStreetAddress(addressLine);
  }
}
