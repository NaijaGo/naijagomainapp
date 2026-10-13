import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/models/product.dart';
import 'package:naija_go/providers/cart_provider.dart';
import 'package:naija_go/widgets/product_color_selection.dart';
import 'package:naija_go/theme/app_theme.dart';

Product fixture({
  int stock = 5,
  List<String> colors = const ['Black', 'Royal Blue'],
  List<String> sizes = const ['S', 'M'],
}) => Product(
  id: 'fixture',
  name: 'Shirt',
  description: 'Actual seller options',
  price: 200,
  category: 'Fashion',
  stockQuantity: stock,
  vendorId: 'fixture-vendor',
  availableColors: colors,
  availableSizes: sizes,
);
void main() {
  test(
    'different colours and sizes remain distinct through cart payload/removal',
    () {
      final product = fixture(), cart = CartProvider();
      expect(
        cart.addProduct(product, selectedSize: 'S', selectedColor: 'Black'),
        isTrue,
      );
      expect(
        cart.addProduct(product, selectedSize: 'M', selectedColor: 'Black'),
        isTrue,
      );
      expect(
        cart.addProduct(
          product,
          selectedSize: 'M',
          selectedColor: 'Royal Blue',
        ),
        isTrue,
      );
      expect(cart.items.length, 3);
      expect(cart.totalAmount, 600);
      final blue = cart.items.values.firstWhere(
        (item) => item.selectedColor == 'Royal Blue',
      );
      expect(blue.toJson()['selectedColor'], 'Royal Blue');
      expect(blue.toJson()['selectedSize'], 'M');
      expect(blue.displayName, contains('Royal Blue'));
      cart.removeSingleItem(
        product.id,
        selectedSize: 'S',
        selectedColor: 'Black',
      );
      expect(cart.items.length, 2);
      cart.removeItem(
        product.id,
        selectedSize: 'M',
        selectedColor: 'Royal Blue',
      );
      expect(cart.items.length, 1);
    },
  );
  test(
    'options cannot bypass total stock or silently choose an unavailable colour/size',
    () {
      final cart = CartProvider(), product = fixture(stock: 2);
      expect(cart.addProduct(product), isFalse);
      expect(
        cart.addProduct(product, selectedSize: 'M', selectedColor: 'Red'),
        isFalse,
      );
      expect(
        cart.addProduct(product, selectedSize: 'XXL', selectedColor: 'Black'),
        isFalse,
      );
      expect(
        cart.addProduct(product, selectedSize: 'S', selectedColor: 'Black'),
        isTrue,
      );
      expect(
        cart.addProduct(
          product,
          selectedSize: 'M',
          selectedColor: 'Royal Blue',
        ),
        isTrue,
      );
      expect(
        cart.addProduct(
          product,
          selectedSize: 'S',
          selectedColor: 'Royal Blue',
        ),
        isFalse,
      );
    },
  );
  test('legacy plain products still add without options', () {
    final cart = CartProvider();
    expect(cart.addProduct(fixture(colors: [], sizes: [])), isTrue);
    expect(
      cart.items.values.single.toJson().containsKey('selectedColor'),
      isFalse,
    );
  });
  test(
    'JSON object sizes and custom dimensions are parsed without map labels',
    () {
      final base = {
        '_id': 'fixture',
        'name': 'Sofa',
        'description': 'Actual product',
        'price': 100,
        'category': 'Furniture',
        'stockQuantity': 2,
        'vendor': 'vendor',
        'availableColors': ['Cream'],
      };
      final shirt = Product.fromJson({
        ...base,
        'sizeData': {
          'type': 'clothing',
          'sizes': [
            {'value': 'M', 'label': 'Medium'},
          ],
        },
        'availableSizes': [
          {'value': 'M', 'label': 'Medium'},
        ],
      });
      expect(shirt.availableSizes, ['M']);
      expect(shirt.toJson()['availableColors'], ['Cream']);
      final sofa = Product.fromJson({
        ...base,
        'sizeData': {
          'type': 'custom',
          'customDimensions': [
            {
              'length': 10,
              'width': 20,
              'height': 30,
              'unit': 'cm',
              'label': 'Small',
            },
          ],
        },
      });
      expect(sofa.hasSizes, isTrue);
      expect(sofa.isCustomDimensions, isTrue);
      final cart = CartProvider();
      expect(
        cart.addProduct(
          sofa,
          selectedColor: 'Cream',
          selectedSize: sofa.sizeData!['customDimensions'][0],
        ),
        isTrue,
      );
    },
  );
  testWidgets('colour labels remain selectable at 320px and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: SingleChildScrollView(
              child: ProductColorSelection(
                colors: const ['Black', 'Royal Blue', 'Custom seller finish'],
                selectedColor: null,
                onChanged: (color) => selected = color,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Royal Blue'));
    expect(selected, 'Royal Blue');
    expect(tester.takeException(), isNull);
  });
}
