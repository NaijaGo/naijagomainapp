import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback onOrderSuccess;

  const CartScreen({super.key, required this.onOrderSuccess});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Product> _recentlyViewedProducts = [];
  bool _isLoadingRecentlyViewed = false;

  @override
  void initState() {
    super.initState();
    _fetchRecentlyViewedProducts();
  }

  Future<void> _fetchRecentlyViewedProducts() async {
    setState(() {
      _isLoadingRecentlyViewed = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/products'),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final allProducts = jsonList
            .map((json) => Product.fromJson(json))
            .toList();

        allProducts.shuffle();

        setState(() {
          _recentlyViewedProducts = allProducts.take(12).toList();
        });
      } else {
        _createSimplePlaceholderProducts();
      }
    } catch (e) {
      debugPrint('Error fetching recently viewed: $e');
      if (!mounted) return;
      _createSimplePlaceholderProducts();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecentlyViewed = false;
        });
      }
    }
  }

  void _createSimplePlaceholderProducts() {
    final placeholderProducts = <Map<String, dynamic>>[
      {
        'id': '1',
        'name': 'Wireless Bluetooth Headphones',
        'price': 25000.0,
        'stockQuantity': 15,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Headphones',
        ],
        'vendorBusinessName': 'Tech Store',
        'description':
            'High quality wireless headphones with noise cancellation',
        'category': 'Electronics',
      },
      {
        'id': '2',
        'name': 'Smart Watch Series 5',
        'price': 45000.0,
        'stockQuantity': 8,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Smart+Watch',
        ],
        'vendorBusinessName': 'Gadget Hub',
        'description': 'Feature-rich smart watch with heart rate monitor',
        'category': 'Electronics',
      },
      {
        'id': '3',
        'name': 'Premium Running Shoes',
        'price': 15000.0,
        'stockQuantity': 20,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Shoes'],
        'vendorBusinessName': 'Sports World',
        'description': 'Comfortable running shoes for all terrains',
        'category': 'Sports',
      },
      {
        'id': '4',
        'name': 'Waterproof Backpack',
        'price': 8000.0,
        'stockQuantity': 25,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Backpack',
        ],
        'vendorBusinessName': 'Travel Gear',
        'description': 'Durable waterproof backpack with laptop compartment',
        'category': 'Fashion',
      },
      {
        'id': '5',
        'name': 'Automatic Coffee Maker',
        'price': 35000.0,
        'stockQuantity': 12,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Coffee+Maker',
        ],
        'vendorBusinessName': 'Home Essentials',
        'description': 'Programmable coffee maker with thermal carafe',
        'category': 'Home',
      },
      {
        'id': '6',
        'name': 'Fitness Tracker Band',
        'price': 12000.0,
        'stockQuantity': 18,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Fitness+Band',
        ],
        'vendorBusinessName': 'Health Tech',
        'description': 'Activity tracking fitness band with sleep monitor',
        'category': 'Fitness',
      },
      {
        'id': '7',
        'name': 'Wireless Earbuds',
        'price': 18000.0,
        'stockQuantity': 22,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Earbuds',
        ],
        'vendorBusinessName': 'Audio Tech',
        'description': 'True wireless earbuds with charging case',
        'category': 'Electronics',
      },
      {
        'id': '8',
        'name': 'Gaming Laptop',
        'price': 320000.0,
        'stockQuantity': 5,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Gaming+Laptop',
        ],
        'vendorBusinessName': 'Game Zone',
        'description': 'High performance gaming laptop with RTX graphics',
        'category': 'Electronics',
      },
      {
        'id': '9',
        'name': 'Yoga Mat',
        'price': 6500.0,
        'stockQuantity': 30,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Yoga+Mat',
        ],
        'vendorBusinessName': 'Fitness World',
        'description': 'Non-slip yoga mat with carrying strap',
        'category': 'Fitness',
      },
      {
        'id': '10',
        'name': 'Smartphone X12',
        'price': 185000.0,
        'stockQuantity': 10,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Smartphone',
        ],
        'vendorBusinessName': 'Mobile World',
        'description': 'Latest smartphone with triple camera setup',
        'category': 'Electronics',
      },
      {
        'id': '11',
        'name': 'Air Fryer',
        'price': 28000.0,
        'stockQuantity': 14,
        'imageUrls': [
          'https://placehold.co/400x300/CCCCCC/000000?text=Air+Fryer',
        ],
        'vendorBusinessName': 'Kitchen Pro',
        'description': 'Digital air fryer with multiple cooking functions',
        'category': 'Home',
      },
      {
        'id': '12',
        'name': 'Leather Wallet',
        'price': 5500.0,
        'stockQuantity': 35,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Wallet'],
        'vendorBusinessName': 'Fashion Store',
        'description': 'Genuine leather wallet with multiple card slots',
        'category': 'Fashion',
      },
    ];

    setState(() {
      _recentlyViewedProducts = placeholderProducts
          .map((data) => Product.fromJson(data))
          .toList();
    });
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 2,
    );
    return formatter.format(price);
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    size: 36,
                    color: primaryNavy,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Your cart is empty',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: secondaryBlack,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start shopping to add products to your cart and continue to checkout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: lightGrey, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _fetchRecentlyViewedProducts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryNavy,
                      foregroundColor: white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Browse Products',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem cartItem, int index) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final imageUrl = cartItem.product.imageUrls.isNotEmpty
        ? cartItem.product.imageUrls.first
        : 'https://placehold.co/160x160/CCCCCC/000000?text=No+Image';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(
                      product: cartItem.product,
                      heroTag: 'cart_item_${cartItem.product.id}_$index',
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(width: 92, height: 92, color: white),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 92,
                    height: 92,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: secondaryBlack,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      cartItem.product.vendorBusinessName ??
                          'Vendor unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ),
                  if (cartItem.selectedSize != null &&
                      cartItem.selectedSize!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Size: ${cartItem.selectedSize}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: lightGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatPrice(cartItem.product.price),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _QtyButton(
                        icon: Icons.remove,
                        onTap: () {
                          cartProvider.removeSingleItem(
                            cartItem.product.id,
                            selectedSize: cartItem.selectedSize,
                          );
                        },
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          cartItem.quantity.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: secondaryBlack,
                          ),
                        ),
                      ),
                      _QtyButton(
                        icon: Icons.add,
                        onTap: () {
                          if (cartItem.quantity <
                              cartItem.product.stockQuantity) {
                            cartProvider.addProduct(
                              cartItem.product,
                              selectedSize: cartItem.selectedSize,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Maximum stock reached'),
                                backgroundColor: AppTheme.dangerRed,
                              ),
                            );
                          }
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.dangerRed,
                        ),
                        onPressed: () {
                          cartProvider.removeItem(
                            cartItem.product.id,
                            selectedSize: cartItem.selectedSize,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${cartItem.displayName} removed'),
                              backgroundColor: AppTheme.dangerRed,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection(CartProvider cartProvider) {
    final cartItems = cartProvider.items.values.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cart Items',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: secondaryBlack,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${cartProvider.itemCount} item${cartProvider.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: primaryNavy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Review your selected items before checkout.',
            style: TextStyle(color: lightGrey, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: const Text('Clear Cart'),
                    content: const Text(
                      'Are you sure you want to remove all items from your cart?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          cartProvider.clearCart();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cart cleared'),
                              backgroundColor: accentGreen,
                            ),
                          );
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: AppTheme.dangerRed),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: AppTheme.dangerRed,
                size: 18,
              ),
              label: const Text(
                'Clear Cart',
                style: TextStyle(
                  color: AppTheme.dangerRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            itemBuilder: (context, index) {
              return _buildCartItem(context, cartItems[index], index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildYouMightAlsoLikeSection() {
    if (_isLoadingRecentlyViewed) {
      return Container(
        color: softGrey,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'You Might Also Like',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: secondaryBlack,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 290, child: _buildRecentlyViewedShimmer()),
          ],
        ),
      );
    }

    if (_recentlyViewedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'You Might Also Like',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: secondaryBlack,
                    ),
                  ),
                ),
                Icon(Icons.trending_up_rounded, color: primaryNavy),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 282,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              scrollDirection: Axis.horizontal,
              itemCount: _recentlyViewedProducts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = _recentlyViewedProducts[index];
                final heroTag = 'cart_recent-${product.id}-$index';
                return SizedBox(
                  width: 170,
                  child: _RecentlyViewedProductCard(
                    product: product,
                    heroTag: heroTag,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewedShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      scrollDirection: Axis.horizontal,
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) {
        return Container(
          width: 170,
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          height: 14,
                          width: 80,
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          height: 36,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutBar(CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: secondaryBlack,
                    ),
                  ),
                ),
                Text(
                  _formatPrice(cartProvider.totalAmount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CheckoutScreen(onOrderSuccess: widget.onOrderSuccess),
                    ),
                  );
                },
                icon: const Icon(Icons.payment_outlined, color: white),
                label: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    color: white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  foregroundColor: white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: softGrey,
      appBar: AppBar(
        backgroundColor: white,
        foregroundColor: secondaryBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Cart',
              style: TextStyle(
                color: secondaryBlack,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Review and checkout your selected items',
              style: TextStyle(
                color: lightGrey,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchRecentlyViewedProducts,
            tooltip: 'Refresh products',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.borderGrey.withValues(alpha: 0.7),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: cartProvider.items.isEmpty
                  ? Column(
                      children: [
                        _buildEmptyState(),
                        _buildYouMightAlsoLikeSection(),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCartSection(cartProvider),
                        _buildYouMightAlsoLikeSection(),
                      ],
                    ),
            ),
          ),
          if (cartProvider.itemCount > 0) _buildCheckoutBar(cartProvider),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: primaryNavy),
      ),
    );
  }
}

class _RecentlyViewedProductCard extends StatelessWidget {
  final Product product;
  final String heroTag;

  const _RecentlyViewedProductCard({
    required this.product,
    required this.heroTag,
  });

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 2,
    );
    return formatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ProductDetailScreen(product: product, heroTag: heroTag),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrls.isNotEmpty
                        ? product.imageUrls.first
                        : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image',
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(height: 120, color: white),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: secondaryBlack,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatPrice(product.price),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vendor: ${product.vendorBusinessName ?? 'N/A'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: lightGrey,
                        ),
                      ),
                      if (product.hasSizes) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${product.sizeType} Available',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: lightGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: product.stockQuantity > 0
                              ? () {
                                  cartProvider.addProduct(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${product.name} added to cart',
                                      ),
                                      backgroundColor: accentGreen,
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: product.stockQuantity > 0
                                ? primaryNavy
                                : Colors.grey[300],
                            foregroundColor: product.stockQuantity > 0
                                ? white
                                : Colors.grey[700],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            product.stockQuantity > 0
                                ? 'Add to Cart'
                                : 'Out of Stock',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
}
