import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naija_go/screens/Main/account_screen.dart';
import 'package:naija_go/screens/Main/edit_profile_screen.dart';
import 'package:naija_go/screens/Main/my_wallet_screen.dart';
import 'package:naija_go/theme/app_theme.dart';

const profile = {
  '_id': '000000000000000000000001',
  'firstName': 'Ada',
  'lastName': 'Okoro',
  'email': 'ada@example.invalid',
  'phoneNumber': '08000000000',
  'role': 'buyer',
  'userWalletBalance': 1250,
};
final requests = <http.Request>[];

Future<void> account(
  WidgetTester tester,
  Future<void> Function() action, {
  double width = 390,
  double scale = 1,
  bool optionalFeatures = false,
  VoidCallback? onLogout,
}) async {
  await http.runWithClient(
    () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'local-account-fixture',
      });
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final base = AppTheme.lightTheme;
      final theme = Platform.environment['NAIJAGO_ACCOUNT_FONT_DIR'] == null
          ? base
          : base.copyWith(
              textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: base.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
              appBarTheme: base.appBarTheme.copyWith(
                titleTextStyle: base.appBarTheme.titleTextStyle!.copyWith(
                  fontFamily: 'Roboto',
                ),
              ),
            );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('account-preview'),
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Account'),
                centerTitle: true,
                backgroundColor: Colors.white,
              ),
              body: AccountScreen(onLogout: onLogout ?? () {}),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      await action();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    () => MockClient((request) async {
      requests.add(request);
      Object body = <String, dynamic>{};
      if (request.url.path == '/api/auth/me') body = profile;
      if (request.url.path == '/api/product-requests/config') {
        body = {'enabled': optionalFeatures};
      }
      if (request.url.path == '/api/planned-orders/config') {
        body = {
          'groupOrderingEnabled': optionalFeatures,
          'recurringOrdersEnabled': false,
        };
      }
      if (request.url.path == '/api/auth/saved-items') body = [];
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

Future<void> tapRow(WidgetTester tester, String title) async {
  final row = find.byKey(ValueKey('account-row-$title'));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    final cache = await Directory(
      '.dart_tool/account-appearance-cache',
    ).create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => cache.absolute.path,
        );
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
  setUp(requests.clear);
  testWidgets('account keeps original menu titles and descriptions', (
    tester,
  ) async {
    await account(tester, () async {
      for (final label in [
        'Orders & shopping',
        'My Orders',
        'Track all current & past orders',
        'Pickup Orders',
        'Track preparation and show your pickup QR code',
        'Saved Items (Wishlist)',
        'Easily revisit products you liked',
        'My Wallet / Payment Methods',
        'NaijaGo Subscription',
        'Free delivery plans and personalized offers',
        'Delivery Addresses',
        'Manage your shipping locations',
        'Reviews & Ratings',
        'View products you reviewed',
        'Returns & Disputes',
        'View initiated return requests',
        'Help Center',
        'FAQs, live chat, contact support',
        'Support & preferences',
        'Notification Settings',
        'Manage your notification preferences',
        'Dark Mode Toggle',
        'Switch between light and dark themes',
        'Language & Region',
        'Change app language and region settings',
        'Invite a Friend',
        'Share NaijaGo with your friends',
        'Customer Support',
        'Reach us faster on WhatsApp or place a direct call.',
        'WhatsApp',
        'Call Support',
        'Edit Profile',
        'Log Out',
        'Delete Account',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Wallet balance: \u20a61250.00'), findsNWidgets(2));
      expect(find.text('Coupons & Gift cards'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets('centered profile keeps real customer fields and initials', (
    tester,
  ) async {
    await account(tester, () async {
      for (final value in [
        'Ada Okoro',
        'ada@example.invalid',
        '08000000000',
        'AO',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      final avatar = tester.widget<CircleAvatar>(
        find.byKey(const ValueKey('account-avatar')),
      );
      expect(avatar.radius, 48);
      expect(avatar.backgroundColor, const Color(0xFF111111));
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        Colors.white,
      );
      final row = tester.widget<ListTile>(
        find.byKey(const ValueKey('account-row-My Orders')),
      );
      expect(row.leading, isNull);
      expect(row.onTap, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets('optional tools keep backend readiness gates', (tester) async {
    await account(tester, () async {
      expect(find.text('My product requests'), findsNothing);
      expect(find.text('Group & recurring orders'), findsNothing);
    });
  });
  testWidgets('enabled optional tools keep original wording', (tester) async {
    await account(tester, () async {
      for (final value in [
        'My product requests',
        'Track products NaijaGo is sourcing for you',
        'Group & recurring orders',
        'Plan together or review repeat orders before payment',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
    }, optionalFeatures: true);
  });
  testWidgets('wallet action retains its destination without making payments', (
    tester,
  ) async {
    await account(tester, () async {
      await tapRow(tester, 'My Wallet / Payment Methods');
      expect(find.byType(MyWalletScreen), findsOneWidget);
      expect(requests.any((request) => request.method != 'GET'), isFalse);
      Navigator.of(tester.element(find.byType(MyWalletScreen))).pop();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(find.byType(AccountScreen), findsOneWidget);
    });
  });
  testWidgets('edit profile keeps its existing destination', (tester) async {
    await account(tester, () async {
      await tester.tap(find.byKey(const ValueKey('account-edit-profile')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      Navigator.of(tester.element(find.byType(EditProfileScreen))).pop();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
  testWidgets('dark mode action keeps the existing message', (tester) async {
    await account(tester, () async {
      await tapRow(tester, 'Dark Mode Toggle');
      expect(find.text('This Feature is Coming Soon'), findsOneWidget);
    });
  });
  testWidgets(
    'deletion still requires confirmation and cancel makes no request',
    (tester) async {
      await account(tester, () async {
        await tester.ensureVisible(find.text('Delete Account'));
        await tester.pump();
        await tester.tap(find.text('Delete Account'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Delete Account Permanently?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(requests.any((request) => request.method == 'DELETE'), isFalse);
        expect(
          (await SharedPreferences.getInstance()).getString('jwt_token'),
          isNotNull,
        );
      });
    },
  );
  testWidgets('logout clears the stored login and calls the existing handler', (
    tester,
  ) async {
    var logouts = 0;
    await account(tester, () async {
      await tester.ensureVisible(find.text('Log Out'));
      await tester.pump();
      await tester.tap(find.text('Log Out'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(logouts, 1);
      expect(
        (await SharedPreferences.getInstance()).getString('jwt_token'),
        isNull,
      );
    }, onLogout: () => logouts++);
  });
  testWidgets('account fits narrow screens and enlarged text', (tester) async {
    await account(
      tester,
      () async {
        expect(find.text('My Wallet / Payment Methods'), findsOneWidget);
        await tester.ensureVisible(find.text('Delete Account'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
      width: 320,
      scale: 1.6,
      optionalFeatures: true,
    );
  });
  testWidgets('renders the actual account page for visual review', (
    tester,
  ) async {
    final fonts = Platform.environment['NAIJAGO_ACCOUNT_FONT_DIR'];
    if (fonts != null) {
      await tester.runAsync(() async {
        final text = FontLoader('Roboto');
        for (final name in [
          'roboto-regular.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
        ]) {
          text.addFont(
            Future.value(
              ByteData.sublistView(await File('$fonts/$name').readAsBytes()),
            ),
          );
        }
        await text.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fonts/materialicons-regular.otf').readAsBytes(),
            ),
          ),
        );
        await icons.load();
      });
    }
    await account(tester, () async {
      expect(tester.takeException(), isNull);
      final directory = Platform.environment['NAIJAGO_ACCOUNT_PREVIEW_DIR'];
      if (directory != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('account-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/naijago-account-preview.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  });
}
