// lib/models/address.dart
import 'package:equatable/equatable.dart';

// NOTE: We recommend adding the 'equatable' package to pubspec.yaml
// to use the 'Equatable' mixin for reliable object comparison.

class Address extends Equatable {
  final String id;
  final String name;
  final String phoneNumber;
  final String addressLine;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final String? apartmentNumber;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  const Address({
    this.id = '',
    required this.name,
    required this.phoneNumber,
    required this.addressLine,
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.country = '',
    this.apartmentNumber,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  // Factory constructor to create an Address from a JSON map
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      // Handles '_id' from the backend and standard 'id'
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      // Accepts both 'addressLine' (Flutter default) or 'address' (Backend)
      addressLine: json['addressLine'] ?? json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      // Accepts both 'zipCode' (Flutter default) or 'postalCode' (Backend)
      zipCode: json['zipCode'] ?? json['postalCode'] ?? '',
      country: json['country'] ?? '',
      apartmentNumber: json['apartmentNumber'],
      isDefault: json['isDefault'] ?? false,
      // Safely converts 'num' (int or double) from JSON to 'double?'
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  /// Method to convert Address to a JSON map for Mongoose/API submission.
  /// NOTE: Keys are adjusted to match Mongoose schemas (address, postalCode).
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      // Mongoose expects 'address' for the address line
      'address': addressLine, 
      'city': city,
      'state': state,
      // Mongoose expects 'postalCode'
      'postalCode': zipCode, 
      'country': country,
      'apartmentNumber': apartmentNumber,
      'isDefault': isDefault,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Helper method for creating modified copies
  Address copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? addressLine,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? apartmentNumber,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  // Getter for the complete display address
  String get fullAddress {
    final apt = apartmentNumber != null && apartmentNumber!.isNotEmpty
        ? 'Apt $apartmentNumber, '
        : '';
    // Use proper null-aware operators to combine parts cleanly
    return [
      apt.isNotEmpty ? apt.trim() : null,
      addressLine,
      city,
      state,
      zipCode,
      country,
    ].whereType<String>().join(', ');
  }

  String get postalCode => zipCode;

  // Implementation of Equatable properties for deep equality check
  @override
  List<Object?> get props => [
        id,
        name,
        phoneNumber,
        addressLine,
        city,
        state,
        zipCode,
        country,
        apartmentNumber,
        isDefault,
        latitude,
        longitude,
      ];
}