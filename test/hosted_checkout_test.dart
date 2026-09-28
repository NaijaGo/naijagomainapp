import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/models/hosted_checkout.dart';

void main() {
  test('KoraPay and legacy Squad open only their own HTTPS checkout hosts', () {
    expect(
      HostedCheckout.validatedUrl(
        'korapay',
        'https://checkout.korapay.com/reference/pay',
      ),
      isNotNull,
    );
    expect(
      HostedCheckout.validatedUrl('squad', 'https://pay.squadco.com/reference'),
      isNotNull,
    );
    expect(
      HostedCheckout.validatedUrl(
        'squad',
        'https://sandbox-pay.squadco.com/reference',
      ),
      isNotNull,
    );
    expect(
      HostedCheckout.validatedUrl(
        'korapay',
        'https://pay.squadco.com/reference',
      ),
      isNull,
    );
    expect(
      HostedCheckout.validatedUrl(
        'squad',
        'https://checkout.korapay.com/reference',
      ),
      isNull,
    );
  });
  test(
    'malformed, insecure, credential-bearing and lookalike checkout links are rejected',
    () {
      for (final value in [
        null,
        123,
        '',
        'javascript:alert(1)',
        'http://checkout.korapay.com/pay',
        'https://checkout.korapay.com.evil.example/pay',
        'https://user:secret@checkout.korapay.com/pay',
        'https://checkout.korapay.com:8080/pay',
        ' https://checkout.korapay.com/pay',
      ]) {
        expect(HostedCheckout.validatedUrl('korapay', value), isNull);
      }
    },
  );
  test('unknown providers cannot be treated as a hosted payment provider', () {
    expect(HostedCheckout.supports('korapay'), isTrue);
    expect(HostedCheckout.supports('squad'), isTrue);
    expect(HostedCheckout.supports('unknown'), isFalse);
    expect(
      HostedCheckout.validatedUrl(
        'unknown',
        'https://checkout.korapay.com/pay',
      ),
      isNull,
    );
    expect(HostedCheckout.label('korapay'), 'KoraPay');
  });
}
