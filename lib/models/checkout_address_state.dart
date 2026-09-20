enum CheckoutAddressMode { none, saved, currentLocation, manual }

/// Owns the delivery destination independently of GPS/search bias coordinates.
/// A revision identifies the address an asynchronous lookup or quote belongs to.
class CheckoutAddressState {
  CheckoutAddressMode mode = CheckoutAddressMode.none;
  double? latitude;
  double? longitude;
  bool isReady = false;
  int revision = 0;

  bool get hasCoordinates => latitude != null && longitude != null;

  void select(
    CheckoutAddressMode value, {
    double? latitude,
    double? longitude,
  }) {
    mode = value;
    invalidate();
    if (latitude != null && longitude != null) {
      resolveCoordinates(revision, latitude, longitude);
    }
  }

  void invalidate({bool keepCoordinates = false}) {
    revision++;
    isReady = false;
    if (!keepCoordinates) {
      latitude = null;
      longitude = null;
    }
  }

  bool resolveCoordinates(int expectedRevision, double lat, double lon) {
    if (expectedRevision != revision ||
        mode == CheckoutAddressMode.none ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return false;
    }
    latitude = lat;
    longitude = lon;
    return true;
  }

  bool confirm({required bool fieldsComplete}) {
    isReady =
        mode != CheckoutAddressMode.none && fieldsComplete && hasCoordinates;
    return isReady;
  }

  bool acceptsQuote(int expectedRevision) =>
      isReady && revision == expectedRevision;
}
