import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/models/checkout_address_state.dart';

void main() {
  test('manual selection discards a previous GPS destination and quote', () {
    final state = CheckoutAddressState();
    state.select(
      CheckoutAddressMode.currentLocation,
      latitude: 9,
      longitude: 7,
    );
    state.confirm(fieldsComplete: true);
    final oldRevision = state.revision;
    state.select(CheckoutAddressMode.manual);
    expect(state.mode, CheckoutAddressMode.manual);
    expect(state.hasCoordinates, isFalse);
    expect(state.isReady, isFalse);
    expect(state.acceptsQuote(oldRevision), isFalse);
  });

  test('switching saved addresses replaces coordinates', () {
    final state = CheckoutAddressState();
    state.select(CheckoutAddressMode.saved, latitude: 9, longitude: 7);
    state.select(CheckoutAddressMode.saved, latitude: 8, longitude: 6);
    expect(state.latitude, 8);
    expect(state.longitude, 6);
    expect(state.isReady, isFalse);
  });

  test('late geocode response cannot overwrite a new destination', () {
    final state = CheckoutAddressState();
    state.select(CheckoutAddressMode.manual);
    final lookupRevision = state.revision;
    state.select(CheckoutAddressMode.saved, latitude: 8, longitude: 6);
    expect(state.resolveCoordinates(lookupRevision, 9, 7), isFalse);
    expect(state.latitude, 8);
  });

  test('confirmation requires complete fields and resolved coordinates', () {
    final state = CheckoutAddressState();
    state.select(CheckoutAddressMode.manual);
    expect(state.confirm(fieldsComplete: true), isFalse);
    state.resolveCoordinates(state.revision, 9, 7);
    expect(state.confirm(fieldsComplete: false), isFalse);
    expect(state.confirm(fieldsComplete: true), isTrue);
    expect(state.acceptsQuote(state.revision), isTrue);
    expect(state.mode, CheckoutAddressMode.manual);
  });

  test('editing address invalidates both coordinates and old quotes', () {
    final state = CheckoutAddressState();
    state.select(CheckoutAddressMode.manual, latitude: 9, longitude: 7);
    state.confirm(fieldsComplete: true);
    final oldRevision = state.revision;
    state.invalidate();
    expect(state.hasCoordinates, isFalse);
    expect(state.acceptsQuote(oldRevision), isFalse);
  });

  test(
    'postal metadata edit preserves selected location but invalidates quote',
    () {
      final state = CheckoutAddressState();
      state.select(CheckoutAddressMode.manual, latitude: 9, longitude: 7);
      state.confirm(fieldsComplete: true);
      final oldRevision = state.revision;
      state.invalidate(keepCoordinates: true);
      expect(state.latitude, 9);
      expect(state.isReady, isFalse);
      expect(state.acceptsQuote(oldRevision), isFalse);
    },
  );

  test('invalid coordinates cannot enable checkout', () {
    for (final point in [
      [91.0, 7.0],
      [9.0, 181.0],
      [double.nan, 7.0],
    ]) {
      final state = CheckoutAddressState();
      state.select(
        CheckoutAddressMode.manual,
        latitude: point[0],
        longitude: point[1],
      );
      expect(state.confirm(fieldsComplete: true), isFalse);
    }
  });
}
