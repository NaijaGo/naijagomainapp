import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:naija_go/core/formatters/naira.dart';

void main() {
  group('formatNaira', () {
    const wholeAmounts = {
      0: '₦0',
      500: '₦500',
      1500: '₦1,500',
      10000: '₦10,000',
      150000: '₦150,000',
      1000000: '₦1,000,000',
    };
    for (final entry in wholeAmounts.entries) {
      test('groups ${entry.key} with a single naira symbol', () {
        expect(formatNaira(entry.key), entry.value);
        expect(formatNaira(entry.key.toDouble()), entry.value);
      });
    }

    test('retains kobo and rounds only the displayed value to two places', () {
      expect(formatNaira(1250.50), '₦1,250.50');
      expect(formatNaira(1250.05), '₦1,250.05');
      expect(formatNaira(0.01), '₦0.01');
      expect(formatNaira(1234.567), '₦1,234.57');
      expect(formatNaira(0.1 + 0.2), '₦0.30');
    });

    test(
      'preserves the existing fixed-decimal wallet/checkout presentation',
      () {
        expect(formatNaira(0, alwaysShowDecimals: true), '₦0.00');
        expect(formatNaira(1500, alwaysShowDecimals: true), '₦1,500.00');
        expect(formatNaira(1250.5, alwaysShowDecimals: true), '₦1,250.50');
      },
    );

    test('accepts numeric API strings and correctly grouped values', () {
      expect(formatNaira('150000'), '₦150,000');
      expect(formatNaira(' 1250.50 '), '₦1,250.50');
      expect(formatNaira('1,000,000'), '₦1,000,000');
      expect(formatNaira('₦1,250.50'), '₦1,250.50');
      expect(formatNaira('₦ 1,250.50'), '₦1,250.50');
      expect(formatNaira(formatNaira(1250.5)), '₦1,250.50');
    });

    test('keeps negative amounts and refund signs', () {
      expect(formatNaira(-1500), '-₦1,500');
      expect(formatNaira(-1250.5), '-₦1,250.50');
      expect(formatNaira('-₦1,250.50'), '-₦1,250.50');
      expect(formatNaira('₦-1,250.50'), '-₦1,250.50');
      expect(formatNaira(-0.0, alwaysShowDecimals: true), '₦0.00');
    });

    test(
      'handles missing, malformed and nonfinite values without inventing zero',
      () {
        for (final value in [
          null,
          '',
          ' ',
          'not money',
          '12,34',
          '1,2,3',
          '₦₦500',
          true,
          <int>[],
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          expect(formatNaira(value), '—', reason: '$value');
        }
      },
    );

    test('uses Nigerian grouping independently of the device locale', () {
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);
      Intl.defaultLocale = 'de_DE';
      expect(formatNaira(1234567.89), '₦1,234,567.89');
    });

    test('does not mutate numbers, source maps or calculation inputs', () {
      final item = <String, dynamic>{'price': 1250.5, 'quantity': 3};
      final before = Map<String, dynamic>.of(item);
      expect(formatNaira(item['price']), '₦1,250.50');
      expect(item, before);
      expect(item['price'] * item['quantity'], 3751.5);
    });
  });
}
