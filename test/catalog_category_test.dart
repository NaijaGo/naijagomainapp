import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/models/catalog_category.dart';
import '../lib/models/product.dart';
import '../lib/services/catalog_category_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = File('assets/catalog_taxonomy.v1.json').readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('23 parents and 186 children retain exact labels, ordering and IDs', () {
    final hierarchy = CatalogHierarchy.fromJson(data);
    final categories = hierarchy.categoryMap();
    expect(categories.length, 23);
    expect(categories.values.expand((value) => value).length, 186);
    expect(categories.keys.first, 'Home & Office');
    expect(categories['Photography']!.last, 'Content Creator Equipment');
    expect(categories['Restaurant'], [
      'Meals',
      'Fast Food',
      'Local Dishes',
      'Pastries',
      'Drinks',
      'Catering',
    ]);
    expect(hierarchy.categoryMap(includeRestaurant: false).length, 22);
    expect(hierarchy.referencesFor('Fashion', 'Footwear'), isEmpty);
  });
  test(
    'references resolve parent-scoped aliases without inventing identities',
    () {
      final hierarchy = CatalogHierarchy.fromJson({
        ...data,
        'referencesReady': true,
      });
      expect(
        hierarchy.referencesFor('Health & Beauty', 'Medicine'),
        hierarchy.referencesFor('Cosmetics & Beauty > Medicine'),
      );
      expect(
        hierarchy.referencesFor('Fashion', 'Men'),
        hierarchy.referencesFor("Fashion > Men's Fashion"),
      );
      expect(
        hierarchy.referencesFor('Phones & Tablets', 'Accessories'),
        hierarchy.referencesFor('Phones & Tablets > Mobile Phone Accessories'),
      );
      expect(hierarchy.referencesFor('Fashion', 'Accessories'), isEmpty);
      expect(hierarchy.referencesFor('Photography', 'Not configured'), isEmpty);
      expect(hierarchy.referencesFor('Fashion > Footwear', 'Watches'), isEmpty);
    },
  );
  test(
    'corrupt hierarchy, identity, label or parent relationships fail closed',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (value) => value['version'] = 2,
        (value) => value['checksum'] = 'bad',
        (value) => (value['categories'] as List).removeLast(),
        (value) => value['categories'][0]['children'][0]['parentId'] =
            value['categories'][1]['id'],
        (value) => value['categories'][1]['id'] = value['categories'][0]['id'],
        (value) => value['categories'][0]['label'] = 'Renamed',
      ]) {
        final bad = jsonDecode(raw) as Map<String, dynamic>;
        mutate(bad);
        expect(() => CatalogHierarchy.fromJson(bad), throwsFormatException);
      }
    },
  );
  test(
    'read-only API loads stable refs; bundled and cached data cannot enable writes',
    () async {
      final updates = <bool>[];
      final client = MockClient((request) async {
        expect(request.url.path, '/api/categories');
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode({...data, 'referencesReady': true}),
          200,
        );
      });
      final result = await CatalogCategoryService.load(
        client: client,
        assetLoader: () async => raw,
        onReady: (value) => updates.add(value.referencesReady),
      );
      expect(result.referencesReady, isTrue);
      expect(updates, [false, true]);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString(CatalogCategoryService.cacheKey)!,
        )['referencesReady'],
        isFalse,
      );
    },
  );
  test(
    'older, unavailable and malformed API responses retain the generated fallback',
    () async {
      for (final reply in [
        http.Response('', 404),
        http.Response('{}', 200),
        http.Response('invalid', 200),
      ]) {
        final result = await CatalogCategoryService.load(
          client: MockClient((_) async => reply),
          assetLoader: () async => raw,
        );
        expect(result.categoryMap().length, 23);
        expect(result.referencesReady, isFalse);
      }
      final result = await CatalogCategoryService.load(
        client: MockClient((_) async => throw const SocketException('fixture')),
        assetLoader: () async => raw,
      );
      expect(result.categoryMap().length, 23);
      expect(result.referencesReady, isFalse);
    },
  );
  test(
    'old products and split medicine/food fields retain their labels and restrictions',
    () {
      Product product(String category, String subcategory) => Product.fromJson({
        '_id': 'fixture',
        'name': 'fixture',
        'description': '',
        'price': 1,
        'category': category,
        'subcategory': subcategory,
        'stockQuantity': 1,
        'vendor': 'vendor',
      });
      final medicine = product('Health & Beauty', 'Medicine');
      expect(medicine.isMedicine, isTrue);
      expect(medicine.categoryId, isNull);
      expect(medicine.toJson()['category'], 'Health & Beauty');
      expect(medicine.toJson()['subcategory'], 'Medicine');
      expect(product('Restaurant', 'Meals').isRestaurantItem, isTrue);
      expect(
        product('Food & Beverage', 'Restaurant Equipment').isRestaurantItem,
        isFalse,
      );
      final referenced = Product.fromJson({
        ...medicine.toJson(),
        'categoryId': 'parent',
        'subcategoryId': 'child',
      });
      expect(referenced.categoryId, 'parent');
      expect(referenced.subcategoryId, 'child');
    },
  );
  test(
    'equivalent combined and split aliases resolve to the same scoped child',
    () {
      final hierarchy = CatalogHierarchy.fromJson({
        ...data,
        'referencesReady': true,
      });
      expect(
        hierarchy.referencesFor('Fashion > Men', "Men's Fashion"),
        hierarchy.referencesFor("Fashion > Men's Fashion"),
      );
      expect(hierarchy.referencesFor('Fashion > Men', 'Watches'), isEmpty);
    },
  );
  test(
    'contradictory equipment evidence cannot cancel food or medicine flags',
    () {
      Product product(Map<String, dynamic> values) => Product.fromJson({
        '_id': 'fixture',
        'name': 'Fixture',
        'description': '',
        'price': 1,
        'category': 'Legacy',
        'subcategory': '',
        'stockQuantity': 1,
        'vendor': 'vendor',
        ...values,
      });
      expect(
        product({
          'category': 'Restaurant',
          'subcategory': 'Restaurant Equipment',
        }).isRestaurantItem,
        isTrue,
      );
      expect(
        product({
          'category': 'Food & Beverage > Restaurant Equipment',
          'subcategory': 'Meals',
        }).isRestaurantItem,
        isTrue,
      );
      expect(
        product({
          'category': 'Food & Beverage',
          'subcategory': 'Restaurant Equipment',
        }).isRestaurantItem,
        isFalse,
      );
      for (final flag in [
        'requiresPrescription',
        'requiresPharmacistApproval',
      ]) {
        final value = product({'medicineAccess': 'otc', flag: true});
        expect(value.isMedicine, isTrue);
        expect(value.isRestrictedMedicine, isTrue);
        expect(value.canBuyDirectly, isFalse);
      }
    },
  );
}
