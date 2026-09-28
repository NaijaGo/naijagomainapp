/// Hosted URLs come only from the authenticated backend, never a gateway callback.
class HostedCheckout {
  static bool supports(String provider) =>
      provider == 'korapay' || provider == 'squad';

  static String label(String provider) =>
      provider == 'korapay' ? 'KoraPay' : 'Squad';

  static Uri? validatedUrl(String provider, dynamic value) {
    if (value is! String || value.trim() != value) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }
    final allowed = switch (provider) {
      'korapay' => {'checkout.korapay.com'},
      'squad' => {'pay.squadco.com', 'sandbox-pay.squadco.com'},
      _ => <String>{},
    };
    return allowed.contains(uri.host) ? uri : null;
  }
}
