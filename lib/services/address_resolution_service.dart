import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import 'address_autocomplete_service.dart';

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

  static Future<ResolvedAddress> resolveFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final remoteFirst = kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;
    if (remoteFirst) {
      final remote = await _resolveRemoteAddress(latitude, longitude);
      if (remote != null) return remote;
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(_reverseGeocodeTimeout);
      if (placemarks.isNotEmpty) return _buildNativeResolvedAddress(placemarks);
    } catch (error) {
      debugPrint('Native reverse geocoding failed: $error');
    }

    if (!remoteFirst) {
      final remote = await _resolveRemoteAddress(latitude, longitude);
      if (remote != null) return remote;
    }

    throw Exception('No address found');
  }

  static Future<ResolvedAddress?> _resolveRemoteAddress(
    double latitude,
    double longitude,
  ) async {
    try {
      final remote = await AddressAutocompleteService().reverseGeocode(latitude, longitude);
      if (remote == null) return null;
      return ResolvedAddress(
        addressLine: remote.address,
        city: remote.city,
        postalCode: remote.postalCode,
        country: remote.country,
        formattedAddress: remote.label,
        placemark: const Placemark(),
      );
    } catch (error) {
      debugPrint('Backend reverse geocoding failed: ${error.runtimeType}');
      return null;
    }
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
