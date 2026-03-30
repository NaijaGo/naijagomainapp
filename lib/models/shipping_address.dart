class ShippingAddress {
  final String address;
  final String city;
  final String postalCode;
  final String country;

  ShippingAddress({
    required this.address,
    required this.city,
    required this.postalCode,
    required this.country,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      address: json['address'] ?? 'N/A',
      city: json['city'] ?? 'N/A',
      postalCode: json['postalCode'] ?? 'N/A',
      country: json['country'] ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
    };
  }
}