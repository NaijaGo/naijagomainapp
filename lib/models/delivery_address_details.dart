double? parseDeliveryCoordinate(Object? value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value.trim())
    : null;
bool validDeliveryCoordinates(double? lat, double? lon) =>
    lat != null &&
    lon != null &&
    lat.isFinite &&
    lon.isFinite &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180 &&
    !(lat == 0 && lon == 0);

class DeliveryAddressDetails {
  final String address,
      street,
      area,
      landmark,
      city,
      state,
      country,
      postalCode;
  const DeliveryAddressDetails({
    this.address = '',
    this.street = '',
    this.area = '',
    this.landmark = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.postalCode = '',
  });
  factory DeliveryAddressDetails.fromJson(Map<String, dynamic> json) {
    String read(String key) =>
        json[key] is String ? (json[key] as String).trim() : '';
    return DeliveryAddressDetails(
      address: read('address').isNotEmpty
          ? read('address')
          : read('addressLine'),
      street: read('street'),
      area: read('area'),
      landmark: read('landmark'),
      city: read('city'),
      state: read('state'),
      country: read('country'),
      postalCode: read('postalCode'),
    );
  }
  bool get complete =>
      address.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      country.trim().isNotEmpty;
  Map<String, dynamic> toJson() => {
    'address': address.trim(),
    'street': street.trim(),
    'area': area.trim(),
    'landmark': landmark.trim(),
    'city': city.trim(),
    'state': state.trim(),
    'country': country.trim(),
    'postalCode': postalCode.trim(),
  };
}
