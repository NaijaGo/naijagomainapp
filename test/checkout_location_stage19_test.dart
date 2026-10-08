import 'package:geocoding/geocoding.dart';
import 'package:naija_go/services/address_resolution_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naija_go/models/delivery_address_details.dart';
import 'package:naija_go/models/checkout_address_state.dart';
import 'package:naija_go/models/address.dart';
import 'package:naija_go/services/address_autocomplete_service.dart';
import 'package:naija_go/services/location_access_service.dart';
import 'package:naija_go/widgets/checkout_location_map.dart';
import 'helpers/location_tiles.dart';

class PermissionGps extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  Completer<LocationPermission>? pending;
  int requests = 0;
  int precisionRequests = 0;
  LocationAccuracyStatus accuracy = LocationAccuracyStatus.reduced;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return pending?.future ?? permission;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracy;
  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async {
    precisionRequests++;
    return accuracy;
  }
}

class NativeAddress extends GeocodingPlatform {
  final Placemark placemark;
  NativeAddress(this.placemark);
  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    String? localeIdentifier,
  }) async => [placemark];
}

void main() {
  for (final scenario in <String, List<double?>>{
    'valid': [9.08, 7.46],
    'null': [null, 7],
    'NaN': [double.nan, 7],
    'infinity': [9, double.infinity],
    'latitude range': [91, 7],
    'longitude range': [9, -181],
    'zero pair': [0, 0],
    'single zero': [0, 7],
  }.entries) {
    test('coordinate validation ${scenario.key}', () {
      expect(
        validDeliveryCoordinates(scenario.value[0], scenario.value[1]),
        scenario.key == 'valid' || scenario.key == 'single zero',
      );
    });
  }
  test(
    'structured address parsing retains fields without fabricating missing values',
    () {
      final d = DeliveryAddressDetails.fromJson({
        'addressLine': '3rd Avenue',
        'street': 'Avenue',
        'area': 'Gwarinpa',
        'city': 'Abuja',
        'state': 'FCT',
        'country': 'Nigeria',
      });
      expect(d.complete, true);
      expect(d.street, 'Avenue');
      expect(d.area, 'Gwarinpa');
      expect(d.state, 'FCT');
      expect(d.postalCode, '');
      expect(d.landmark, '');
      final partial = DeliveryAddressDetails.fromJson({
        'address': 'Street',
        'city': 'Abuja',
        'country': 'Nigeria',
      });
      expect(partial.state, '');
      expect(partial.area, '');
    },
  );
  test('saved address parses strings and rejects zero/malformed pairs', () {
    final a = Address.fromJson({
      'latitude': '9.08',
      'longitude': '7.46',
      'state': 'FCT',
      'area': 'Gwarinpa',
    });
    expect(a.latitude, 9.08);
    expect(a.longitude, 7.46);
    expect(a.toJson()['area'], 'Gwarinpa');
    for (final pair in [
      [0, 0],
      [null, 7],
      ['bad', 7],
    ]) {
      final a = Address.fromJson({'latitude': pair[0], 'longitude': pair[1]});
      expect(a.latitude, isNull);
      expect(a.longitude, isNull);
    }
  });
  test('GPS after search and reverse lookup after pin movement are stale', () {
    final s = CheckoutAddressState()
      ..select(CheckoutAddressMode.currentLocation);
    final gps = s.revision;
    s.select(CheckoutAddressMode.manual, latitude: 9, longitude: 7);
    expect(s.resolveCoordinates(gps, 8, 6), false);
    final reverse = s.revision;
    s.select(CheckoutAddressMode.manual, latitude: 9.1, longitude: 7.1);
    expect(s.acceptsQuote(reverse), false);
    expect(s.resolveCoordinates(reverse, 8, 6), false);
    expect(s.latitude, 9.1);
  });
  test(
    'address corrections preserve destination and invalidate old summary',
    () {
      final s = CheckoutAddressState()
        ..select(CheckoutAddressMode.manual, latitude: 9, longitude: 7);
      s.confirm(fieldsComplete: true);
      final quote = s.revision;
      s.invalidate(keepCoordinates: true);
      s.selectedAddress = const DeliveryAddressDetails(
        address: 'Corrected gate',
        city: 'Abuja',
        country: 'Nigeria',
      );
      expect(s.latitude, 9);
      expect(s.longitude, 7);
      expect(s.acceptsQuote(quote), false);
      expect(s.confirm(fieldsComplete: s.selectedAddress.complete), true);
    },
  );
  for (final permission in [
    LocationPermission.whileInUse,
    LocationPermission.denied,
    LocationPermission.deniedForever,
    LocationPermission.unableToDetermine,
  ]) {
    test('permission ${permission.name}', () async {
      final old = GeolocatorPlatform.instance;
      final fake = PermissionGps()..permission = permission;
      GeolocatorPlatform.instance = fake;
      addTearDown(() => GeolocatorPlatform.instance = old);
      final result = await LocationAccessService.ensureAccess();
      expect(result.granted, permission == LocationPermission.whileInUse);
      expect(
        fake.requests,
        permission == LocationPermission.denied ||
                permission == LocationPermission.unableToDetermine
            ? 1
            : 0,
      );
    });
  }
  test('disabled services fail before permission prompt', () async {
    final old = GeolocatorPlatform.instance;
    final fake = PermissionGps()..enabled = false;
    GeolocatorPlatform.instance = fake;
    addTearDown(() => GeolocatorPlatform.instance = old);
    expect(
      (await LocationAccessService.ensureAccess()).issue,
      LocationAccessIssue.servicesDisabled,
    );
    expect(fake.requests, 0);
  });
  test(
    'overlapping main and checkout permission requests share one pending flow',
    () async {
      final old = GeolocatorPlatform.instance;
      final fake = PermissionGps()..pending = Completer<LocationPermission>();
      GeolocatorPlatform.instance = fake;
      addTearDown(() => GeolocatorPlatform.instance = old);
      final first = LocationAccessService.ensureAccess();
      final second = LocationAccessService.ensureAccess();
      expect(identical(first, second), true);
      expect(LocationAccessService.permissionRequestPending, true);
      await Future<void>.delayed(Duration.zero);
      expect(fake.requests, 1);
      fake.pending!.complete(LocationPermission.whileInUse);
      expect((await first).granted, true);
      await second;
      expect(LocationAccessService.permissionRequestPending, false);
    },
  );
  test('iOS precision is rechecked rather than assumed', () async {
    final old = GeolocatorPlatform.instance;
    final fake = PermissionGps();
    GeolocatorPlatform.instance = fake;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() {
      GeolocatorPlatform.instance = old;
      debugDefaultTargetPlatformOverride = null;
    });
    expect(
      await LocationAccessService.requestPreciseLocationIfNeeded(),
      LocationAccuracyStatus.reduced,
    );
    expect(fake.precisionRequests, 1);
  });
  test('reverse response cannot move requested coordinates', () async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'local-test-token'});
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'address': {
            'addressLine': '3rd Avenue',
            'city': 'Abuja',
            'state': 'FCT',
            'area': 'Gwarinpa',
            'country': 'Nigeria',
            'latitude': 0,
            'longitude': 0,
          },
        }),
        200,
      ),
    );
    addTearDown(client.close);
    await http.runWithClient(() async {
      final a = await AddressAutocompleteService().reverseGeocode(9.08, 7.46);
      expect(a!.latitude, 9.08);
      expect(a.longitude, 7.46);
      expect(a.details.state, 'FCT');
      expect(a.postalCode, '');
    }, () => client);
  });
  testWidgets(
    'map initializes without destination, tap selects and search updates camera',
    (tester) async {
      final selected = <List<double>>[];
      Widget map(double? lat, double? lon) => MaterialApp(
        home: Scaffold(
          body: CheckoutLocationMap(
            latitude: lat,
            longitude: lon,
            tileProvider: LocationTestTiles(),
            onSelected: (p) => selected.add([p.latitude, p.longitude]),
          ),
        ),
      );
      await tester.pumpWidget(map(null, null));
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      expect(find.byKey(const Key('delivery-location-pin')), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(selected, isNotEmpty);
      expect(
        validDeliveryCoordinates(selected.last[0], selected.last[1]),
        true,
      );
      await tester.pumpWidget(map(9.08, 7.46));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TileLayer));
      expect(MapCamera.of(context).center.latitude, closeTo(9.08, 0.000001));
      expect(MapCamera.of(context).center.longitude, closeTo(7.46, 0.000001));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'native iOS/Android fields normalize without mandatory postcode/state/area',
    () async {
      final old =
          GeocodingPlatform.instance ?? NativeAddress(const Placemark());
      addTearDown(() => GeocodingPlatform.instance = old);
      for (final complete in [true, false]) {
        GeocodingPlatform.instance = NativeAddress(
          Placemark(
            subThoroughfare: 'Plot 10',
            thoroughfare: 'Avenue',
            subLocality: complete ? 'Gwarinpa' : null,
            locality: 'Abuja',
            administrativeArea: complete ? 'FCT' : null,
            country: 'Nigeria',
            postalCode: complete ? '900001' : null,
          ),
        );
        final result = await AddressResolutionService.resolveFromCoordinates(
          9.08,
          7.46,
        );
        expect(result.addressLine, 'Plot 10 Avenue');
        expect(result.street, 'Avenue');
        expect(result.city, 'Abuja');
        expect(result.country, 'Nigeria');
        expect(result.postalCode, complete ? '900001' : '');
        expect(result.state, complete ? 'FCT' : '');
        expect(result.area, complete ? 'Gwarinpa' : '');
      }
    },
  );
}
