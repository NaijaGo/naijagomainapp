import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants.dart'
    hide lightGrey, primaryNavy, secondaryBlack, softGrey, white;
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../services/customer_location_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'product_detail_screen.dart';

const Color primaryNavy = AppTheme.primaryNavy;
const Color secondaryBlack = AppTheme.secondaryBlack;
const Color softGrey = AppTheme.softGrey;
const Color white = AppTheme.cardWhite;
const Color borderGrey = AppTheme.borderGrey;
const Color lightGrey = AppTheme.mutedText;

enum _RestaurantFilter { all, openNow, breakfast, lunch, dinner }

class RestaurantFoodScreen extends StatefulWidget {
  const RestaurantFoodScreen({super.key});

  @override
  State<RestaurantFoodScreen> createState() => _RestaurantFoodScreenState();
}

class _RestaurantFoodScreenState extends State<RestaurantFoodScreen> {
  final _currency = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  );
  List<Product> _products = [];
  _RestaurantFilter _filter = _RestaurantFilter.all;
  bool _isLoading = true;
  String? _errorMessage;
  double? _customerLatitude;
  double? _customerLongitude;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final location = await CustomerLocationService().getSavedCustomerLocation();
    _customerLatitude = location?.latitude;
    _customerLongitude = location?.longitude;

    final query = <String, String>{};
    if (_customerLatitude != null && _customerLongitude != null) {
      query['lat'] = _customerLatitude!.toString();
      query['lng'] = _customerLongitude!.toString();
      query['radiusKm'] = '15';
      query['sort'] = 'nearby';
    }

    switch (_filter) {
      case _RestaurantFilter.openNow:
        query['openNow'] = 'true';
        break;
      case _RestaurantFilter.breakfast:
        query['mealType'] = 'breakfast';
        break;
      case _RestaurantFilter.lunch:
        query['mealType'] = 'lunch';
        break;
      case _RestaurantFilter.dinner:
        query['mealType'] = 'dinner';
        break;
      case _RestaurantFilter.all:
        break;
    }

    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/products/restaurants$suffix'),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final products = decoded is List
            ? decoded
                  .whereType<Map>()
                  .map(
                    (item) => Product.fromJson(Map<String, dynamic>.from(item)),
                  )
                  .toList()
            : <Product>[];
        setState(() {
          _products = products;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load restaurant foods.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please check your connection and try again.';
      });
    }
  }

  List<Product> get _visibleProducts {
    final filtered = _products.where((product) {
      switch (_filter) {
        case _RestaurantFilter.all:
          return true;
        case _RestaurantFilter.openNow:
          return product.isWithinRestaurantOrderWindow;
        case _RestaurantFilter.breakfast:
          return _matchesMeal(product, ['breakfast', 'tea', 'coffee']);
        case _RestaurantFilter.lunch:
          return _matchesMeal(product, ['lunch', 'rice', 'swallow', 'meal']);
        case _RestaurantFilter.dinner:
          return _matchesMeal(product, ['dinner', 'grill', 'soup']);
      }
    }).toList();

    filtered.sort((left, right) {
      final leftOpen = left.isWithinRestaurantOrderWindow;
      final rightOpen = right.isWithinRestaurantOrderWindow;
      if (leftOpen != rightOpen) return leftOpen ? -1 : 1;
      final leftDistance =
          left.distanceKmFrom(_customerLatitude, _customerLongitude) ??
          double.infinity;
      final rightDistance =
          right.distanceKmFrom(_customerLatitude, _customerLongitude) ??
          double.infinity;
      return leftDistance.compareTo(rightDistance);
    });
    return filtered;
  }

  bool _matchesMeal(Product product, List<String> keywords) {
    final source =
        '${product.name} ${product.category} ${product.description} ${product.foodInformation ?? ''}'
            .toLowerCase();
    return keywords.any(source.contains);
  }

  String _imageUrl(Product product) {
    if (product.imageUrls.isEmpty) {
      return 'https://placehold.co/500x380/201208/FFE4C4?text=Food';
    }
    final url = product.imageUrls.first;
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$baseUrl$url';
    return '$baseUrl/$url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softGrey,
      appBar: AppBar(
        title: const Text(
          'Restaurants',
          style: TextStyle(color: secondaryBlack, fontWeight: FontWeight.w800),
        ),
        backgroundColor: white,
        foregroundColor: secondaryBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: primaryNavy,
        onRefresh: _loadFoods,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildFilters()),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverGrid.builder(
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    mainAxisExtent: 330,
                  ),
                  itemBuilder: (_, _) => _buildSkeletonCard(),
                ),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildState(
                  Icons.wifi_off_rounded,
                  _errorMessage!,
                  action: 'Retry',
                  onTap: _loadFoods,
                ),
              )
            else if (_visibleProducts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No restaurant food available for this filter.',
                    style: TextStyle(
                      color: lightGrey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverGrid.builder(
                  itemCount: _visibleProducts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    mainAxisExtent: 356,
                  ),
                  itemBuilder: (context, index) {
                    return _buildFoodCard(_visibleProducts[index], index);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD08A).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: Color(0xFF9A4B00),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food available now',
                  style: TextStyle(
                    color: secondaryBlack,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Nearby restaurants, meal windows, prices, and distance.',
                  style: TextStyle(color: lightGrey, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = <(_RestaurantFilter, String)>[
      (_RestaurantFilter.all, 'All'),
      (_RestaurantFilter.openNow, 'Open now'),
      (_RestaurantFilter.breakfast, 'Breakfast'),
      (_RestaurantFilter.lunch, 'Lunch'),
      (_RestaurantFilter.dinner, 'Dinner'),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final (filter, label) = filters[index];
          final selected = _filter == filter;
          return ChoiceChip(
            selected: selected,
            label: Text(label),
            onSelected: (_) {
              setState(() => _filter = filter);
              _loadFoods();
            },
            selectedColor: primaryNavy,
            labelStyle: TextStyle(
              color: selected ? white : secondaryBlack,
              fontWeight: FontWeight.w700,
            ),
            side: const BorderSide(color: borderGrey),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }

  Widget _buildFoodCard(Product product, int index) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final heroTag = 'restaurant-food-${product.id}-$index';
    final closed = !product.isWithinRestaurantOrderWindow;
    final outsideRadius = product.isOutsideDeliveryRadius(
      _customerLatitude,
      _customerLongitude,
    );
    final distanceLabel = product.distanceAndMinutesLabel(
      _customerLatitude,
      _customerLongitude,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailScreen(product: product, heroTag: heroTag),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderGrey),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: _imageUrl(product),
                        height: 128,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(height: 128, color: white),
                        ),
                        errorWidget: (_, _, _) => Container(
                          height: 128,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _statusPill(
                          product.restaurantOpenStatusLabel,
                          closed ? Colors.grey.shade800 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: secondaryBlack,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.displayRestaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9A4B00),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        product.displayVendorLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: lightGrey,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (distanceLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          distanceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: lightGrey,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        product.storeHoursLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: lightGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        outsideRadius
                            ? 'Too far for delivery • radius ${product.deliveryRadiusKm.toStringAsFixed(0)} km'
                            : '${product.prepTimeLabel} • Item ${product.displayOrderWindow}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: outsideRadius ? Colors.red.shade700 : lightGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _currency.format(product.price),
                        style: const TextStyle(
                          color: primaryNavy,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: closed ||
                                  product.stockQuantity <= 0 ||
                                  outsideRadius
                              ? null
                              : () {
                                  cart.addProduct(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${product.name} added to cart',
                                      ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: primaryNavy,
                            foregroundColor: white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            closed
                                ? 'Closed'
                                : product.stockQuantity <= 0
                                ? 'Out of Stock'
                                : 'Add to Cart',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(color: white),
      ),
    );
  }

  Widget _buildState(
    IconData icon,
    String message, {
    String? action,
    VoidCallback? onTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: lightGrey, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: secondaryBlack,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (action != null && onTap != null) ...[
              const SizedBox(height: 14),
              ElevatedButton(onPressed: onTap, child: Text(action)),
            ],
          ],
        ),
      ),
    );
  }
}
