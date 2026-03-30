import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:ui' show ImageFilter, lerpDouble;

// Import your existing files
import '../../constants.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'chat_screen.dart';
import 'product_detail_screen.dart';
import 'categories_screen.dart'
    hide
        accentGreen,
        borderGrey,
        lightGrey,
        primaryNavy,
        secondaryBlack,
        softGrey,
        white;
import 'category_products_screen.dart'
    hide
        borderGrey,
        dangerRed,
        lightGrey,
        primaryNavy,
        secondaryBlack,
        softGrey,
        white;

const Color borderGrey = AppTheme.borderGrey;

// ────────────────────────────────────────────────
// NEW SCREEN: Flash Sales
// ────────────────────────────────────────────────
class FlashSalesScreen extends StatelessWidget {
  final List<Product> flashSales;

  const FlashSalesScreen({super.key, required this.flashSales});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softGrey,
      appBar: AppBar(
        title: const Text(
          'Flash Sales',
          style: TextStyle(color: secondaryBlack, fontWeight: FontWeight.w800),
        ),
        backgroundColor: white,
        foregroundColor: secondaryBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: flashSales.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
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
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 42,
                      color: Colors.red,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No flash sale products available.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: secondaryBlack,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                mainAxisExtent: ProductCard.standardCardHeight,
              ),
              itemCount: flashSales.length,
              itemBuilder: (context, index) {
                final product = flashSales[index];
                final heroTag = 'flash_sales-${product.id}-$index';
                return ProductCard(
                  product: product,
                  heroTag: heroTag,
                  showFlashBadge: true,
                );
              },
            ),
    );
  }
}

// ────────────────────────────────────────────────
// UTILITY: Time-based greeting
// ────────────────────────────────────────────────
String getTimeBasedGreeting(String firstName) {
  final hour = DateTime.now().hour;

  if (hour < 12) {
    return 'Good Morning, $firstName!';
  } else if (hour < 17) {
    return 'Good Afternoon, $firstName!';
  } else {
    return 'Good Evening, $firstName!';
  }
}

// ────────────────────────────────────────────────
// SCREEN: Search Screen (unchanged)
// ────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, required this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();
  List<Product> _searchResults = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _performSearch(widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _productService.searchProducts(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      String friendlyMessage = 'An error occurred while searching';

      if (e.toString().contains('404')) {
        friendlyMessage =
            'Search feature is not available yet (endpoint missing)';
      } else if (e.toString().contains('500') ||
          e.toString().contains('Server error')) {
        friendlyMessage =
            'Server is having issues right now... please try again in 30 seconds';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('Connection')) {
        friendlyMessage =
            'Connection problem. Server might be waking up — try again in 15–30 seconds';
      }

      if (mounted) {
        setState(() {
          _errorMessage = '$friendlyMessage\n\nDetails: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStateCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: secondaryBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: lightGrey,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softGrey,
      appBar: AppBar(
        backgroundColor: softGrey,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpacing.md,
        title: Container(
          height: 46,
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _performSearch,
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: const TextStyle(color: lightGrey),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: lightGrey),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: const Icon(Icons.clear, color: lightGrey),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  );
                },
              ),
            ),
            style: const TextStyle(color: secondaryBlack),
          ),
        ),
      ),
      body: _isLoading
          ? _buildStateCard(
              icon: Icons.search_rounded,
              iconColor: primaryNavy,
              title: 'Searching products',
              message: 'We are looking for the best matches for you.',
              action: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: primaryNavy,
                  strokeWidth: 2.4,
                ),
              ),
            )
          : _errorMessage != null
          ? _buildStateCard(
              icon: Icons.error_outline_rounded,
              iconColor: Colors.red,
              title: 'Search unavailable',
              message: _errorMessage!,
              action: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () =>
                      _performSearch(_searchController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: primaryNavy,
                    foregroundColor: white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text('Try again'),
                ),
              ),
            )
          : _searchResults.isEmpty
          ? _buildStateCard(
              icon: Icons.inventory_2_outlined,
              iconColor: primaryNavy,
              title: 'No products found',
              message:
                  'Try another keyword, category, or product name to explore more results.',
            )
          : GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                mainAxisExtent: ProductCard.standardCardHeight,
              ),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final product = _searchResults[index];
                final heroTag = 'search-${product.id}-$index';
                return ProductCard(product: product, heroTag: heroTag);
              },
            ),
    );
  }
}

// ────────────────────────────────────────────────
// SERVICE: Product API calls
// ────────────────────────────────────────────────
class ProductService {
  Future<List<Product>> fetchFlashSales() =>
      _fetchProducts('/api/products/flashsales');
  Future<List<Product>> fetchNewArrivals() =>
      _fetchProducts('/api/products/newarrivals');
  Future<List<Product>> fetchAllProducts() => _fetchProducts('/api/products');
  Future<List<Product>> fetchProductsByCategory(String category) =>
      _fetchProducts('/api/products/category/$category');
  Future<List<Product>> searchProducts(String query) => _fetchProducts(
    '/api/products/search?q=${Uri.encodeQueryComponent(query)}',
  );

  Future<List<Product>> _fetchProducts(String endpoint) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );

    debugPrint('API Response for $endpoint: ${response.statusCode}');
    debugPrint('API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Product.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again.');
    } else if (response.statusCode >= 500) {
      throw Exception('Server error: Please try again later.');
    } else {
      throw Exception(
        'Failed to load data from $endpoint: ${response.statusCode}',
      );
    }
  }
}

// ────────────────────────────────────────────────
// MAIN HOME SCREEN
// ────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _flashSales = [];
  List<Product> _newArrivals = [];
  List<Product> _recommended = [];
  String? _errorMessage;

  final PageController _bannerController = PageController(
    viewportFraction: 0.92,
  );
  final PageController _promoController = PageController(
    viewportFraction: 0.85,
  );
  Timer? _bannerTimer;
  Timer? _promoTimer;

  final TextEditingController _searchController = TextEditingController();

  late final ProductService _productService;

  int _currentBanner = 0;
  int _currentPromo = 0;

  String _userFirstName = 'there'; // fallback

  final List<Map<String, String>> _homeCategories = [
    {"image": "assets/categories/smartphones.jpg", "label": "Phones"},
    {"image": "assets/categories/fashion_women.jpg", "label": "Fashion"},
    {"image": "assets/categories/appliances.jpg", "label": "Electronics"},
    {"image": "assets/categories/sporting_goods.jpg", "label": "Sports"},
    {"image": "assets/categories/groceries.jpg", "label": "Supermarket"},
    {"image": "assets/categories/pharmacy.jpg", "label": "Health"},
  ];

  // Cache settings
  static const String _cacheFlashKey = 'cache_flash_sales';
  static const String _cacheNewKey = 'cache_new_arrivals';
  static const String _cacheRecommendedKey = 'cache_recommended';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const int _cacheExpiryMs = 30 * 60 * 1000; // 30 minutes
  static const List<String> _bannerImages = [
    'assets/Artboard1.jpeg',
    'assets/Artboard2.jpeg',
    'assets/Artboard3.jpeg',
    'assets/Artboard4.jpeg',
    'assets/Artboard5.jpeg',
    'assets/Artboard6.jpeg',
    'assets/Artboard7.jpeg',
  ];
  static const List<String> _promoBanners = [
    'assets/ads1.png',
    'assets/ads2.png',
    'assets/ads3.png',
    'assets/ads4.png',
    'assets/ads5.png',
  ];

  @override
  void initState() {
    super.initState();
    _productService = ProductService();
    _loadUserName();
    _fetchProducts(); // will use cache first + background refresh
    _startAutoScrollTimers();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonString = prefs.getString('user');

    if (userJsonString != null) {
      final userData = jsonDecode(userJsonString);
      final firstName = userData['firstName'] ?? 'there';

      if (mounted) {
        setState(() {
          _userFirstName = firstName;
        });
      }
    }
  }

  Future<void> _fetchProducts({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    _errorMessage = null;

    // ── CASE 1: Load from cache (instant UI - vendor names show immediately) ──
    if (!forceRefresh) {
      final cachedFlash = prefs.getString(_cacheFlashKey);
      final cachedNew = prefs.getString(_cacheNewKey);
      final cachedRecommended = prefs.getString(_cacheRecommendedKey);
      final cacheTimeStr = prefs.getString(_cacheTimestampKey);

      final cacheTime = cacheTimeStr != null
          ? int.tryParse(cacheTimeStr)
          : null;

      if (cacheTime != null &&
          DateTime.now().millisecondsSinceEpoch - cacheTime < _cacheExpiryMs) {
        if (cachedFlash != null ||
            cachedNew != null ||
            cachedRecommended != null) {
          setState(() {
            _flashSales = <Product>[].fromCacheString(cachedFlash);
            _newArrivals = <Product>[].fromCacheString(cachedNew);
            _recommended = <Product>[].fromCacheString(cachedRecommended)
              ..shuffle();
          });
        }
        // Do NOT return here — continue to background refresh
      }
    }

    // ── CASE 2: Always fetch fresh data in background (updates UI when ready) ──
    try {
      final results = await Future.wait([
        _productService.fetchFlashSales(),
        _productService.fetchNewArrivals(),
        _productService.fetchAllProducts(),
      ]);

      if (mounted) {
        setState(() {
          _flashSales = results[0];
          _newArrivals = results[1];
          _recommended = results[2]..shuffle();
        });

        // Save updated data to cache
        await prefs.setString(_cacheFlashKey, results[0].toCacheString());
        await prefs.setString(_cacheNewKey, results[1].toCacheString());
        await prefs.setString(_cacheRecommendedKey, results[2].toCacheString());
        await prefs.setString(
          _cacheTimestampKey,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
    } on Exception catch (e) {
      debugPrint('Error fetching products: $e');
      if (mounted) {
        setState(() {
          if (e.toString().contains('Unauthorized')) {
            _errorMessage = 'Session expired. Please log in again.';
          } else if (e.toString().contains('Server error')) {
            _errorMessage =
                'Server is currently unavailable. Please try again later.';
          } else {
            _errorMessage =
                'An error occurred. Please check your network connection.';
          }
        });
      }
    }
  }

  // ── Auto-scroll timers for banners ─────────────────────────────────────
  void _startAutoScrollTimers() {
    _bannerTimer?.cancel();
    _promoTimer?.cancel();

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_bannerController.hasClients) {
        return;
      }

      if (_bannerImages.isNotEmpty) {
        final next = (_currentBanner + 1) % _bannerImages.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });

    _promoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_promoController.hasClients) {
        return;
      }

      if (_promoBanners.isNotEmpty) {
        final next = (_currentPromo + 1) % _promoBanners.length;
        _promoController.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _promoTimer?.cancel();
    _bannerController.dispose();
    _promoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softGrey,
      body: RefreshIndicator(
        onRefresh: () => _fetchProducts(forceRefresh: true),
        color: primaryNavy,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Collapsing pinned search header ────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _CollapsingSearchHeader(
                searchController: _searchController,
                userFirstName: _userFirstName,
                homeCategories: _homeCategories,
              ),
            ),
            SliverToBoxAdapter(child: _buildBannerCarousel()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

            // ── Flash Sales section ────────────────────────────────────────
            if (_flashSales.isNotEmpty) ...[
              _buildSectionHeader(
                'Flash Sales 🔥',
                onSeeAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          FlashSalesScreen(flashSales: _flashSales),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: ProductListHorizontal(
                  products: _flashSales,
                  sectionKey: 'flash',
                  showFlashBadge: true,
                  showNewBadge: false,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],

            // ── Categories section ─────────────────────────────────────────
            _buildSectionHeader(
              'Categories',
              onSeeAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CategoriesScreen(),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: _buildCategories()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

            // ── New Arrivals section ───────────────────────────────────────
            if (_newArrivals.isNotEmpty) ...[
              _buildSectionHeader('New Arrivals ✨', onSeeAll: null),
              SliverToBoxAdapter(
                child: ProductListHorizontal(
                  products: _newArrivals,
                  sectionKey: 'new',
                  showFlashBadge: false,
                  showNewBadge: true,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],

            SliverToBoxAdapter(child: _buildPromoCarousel()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

            // ── Recommended For You (shuffled) ─────────────────────────────
            if (_recommended.isNotEmpty) ...[
              _buildSectionHeader('Recommended For You', onSeeAll: null),
              ProductListGrid(products: _recommended, sectionKey: 'rec'),
            ],

            // ── Error message (if any) ─────────────────────────────────────
            if (_errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: secondaryBlack,
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => _fetchProducts(forceRefresh: true),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: primaryNavy,
                              foregroundColor: white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Footer ─────────────────────────────────────────────────────
            _buildFooter(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselIndicators({
    required int count,
    required int currentIndex,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final active = i == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 6,
            width: active ? 20 : 6,
            decoration: BoxDecoration(
              color: active ? primaryNavy : borderGrey,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 182,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemCount: _bannerImages.length,
            itemBuilder: (_, i) {
              final active = i == _currentBanner;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  i == 0 ? 16 : 8,
                  active ? 2 : 8,
                  i == _bannerImages.length - 1 ? 16 : 8,
                  active ? 2 : 8,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderGrey),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          _bannerImages[i],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            color: softGrey,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: lightGrey,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.02),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.04),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _buildCarouselIndicators(
          count: _bannerImages.length,
          currentIndex: _currentBanner,
        ),
      ],
    );
  }

  Widget _buildPromoCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _promoController,
            onPageChanged: (i) => setState(() => _currentPromo = i),
            itemCount: _promoBanners.length,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    _promoBanners[i],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: softGrey,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: lightGrey,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _buildCarouselIndicators(
          count: _promoBanners.length,
          currentIndex: _currentPromo,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    final hasAnimation = title.contains('🔥') || title.contains('✨');
    final titleText = hasAnimation
        ? title.substring(0, title.length - 2).trim()
        : title;
    final emoji = hasAnimation ? title.substring(title.length - 2).trim() : '';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: primaryNavy,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    titleText,
                    style: const TextStyle(
                      color: secondaryBlack,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (hasAnimation)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: _AnimatedText(
                        text: emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                ],
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: primaryNavy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final childAspectRatio = constraints.maxWidth < 360 ? 0.82 : 0.90;

        return Container(
          color: softGrey,
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: childAspectRatio,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _homeCategories.length,
            itemBuilder: (context, index) {
              final cat = _homeCategories[index];
              return _buildCategoryCard(
                imagePath: cat["image"] as String,
                label: cat["label"] as String,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard({
    required String imagePath,
    required String label,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CategoriesScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppRadius.sm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFF4F7FB),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const Icon(
                        Icons.image_not_supported,
                        color: lightGrey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondaryBlack,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 36),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Text(
                    'NaijaGo',
                    style: TextStyle(
                      color: primaryNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Discover trusted products from verified vendors across Nigeria.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: lightGrey,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '© 2025 NaijaGo. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// COLLAPSIBLE HEADER DELEGATE
// ────────────────────────────────────────────────
class _CollapsingSearchHeader extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String userFirstName;
  final List<Map<String, String>> homeCategories;

  _CollapsingSearchHeader({
    required this.searchController,
    required this.userFirstName,
    required this.homeCategories,
  });

  void _showPharmacyOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: borderGrey,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Pharmacy',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: secondaryBlack,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to continue.',
                style: TextStyle(fontSize: 13.5, color: lightGrey),
              ),
              const SizedBox(height: 18),
              _buildPharmacyAction(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: primaryNavy,
                title: 'Consult Pharmacist',
                subtitle: 'Chat for quick guidance before you buy.',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildPharmacyAction(
                icon: Icons.local_pharmacy_outlined,
                iconColor: accentGreen,
                title: 'Pharmacy Store',
                subtitle: 'Browse medicine and health essentials.',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryProductsScreen(
                        category: 'Health & Beauty > Medicine',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPharmacyAction({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderGrey),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: secondaryBlack,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: lightGrey,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: lightGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pharmacyShortcut(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPharmacyOptions(context),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderGrey),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  color: primaryNavy,
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pharmacy',
                    style: const TextStyle(
                      color: secondaryBlack,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Shop or chat',
                    style: const TextStyle(
                      color: lightGrey,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: primaryNavy,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.north_east_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    final double searchTop = lerpDouble(10.0, 8.0, t)!;
    final double searchHeight = lerpDouble(48.0, 44.0, t)!;
    final double greetingOpacity = (1.0 - t * 1.45).clamp(0.0, 1.0);
    final double infoTop = lerpDouble(64.0, 54.0, t)!;
    final double headingSize = lerpDouble(16.0, 13.5, t)!;
    final double panelOffset = lerpDouble(0.0, 8.0, t)!;
    return ColoredBox(
      color: softGrey,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: softGrey,
          border: const Border(bottom: BorderSide(color: borderGrey)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: searchTop,
              child: Container(
                height: searchHeight,
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderGrey),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (query) {
                    if (query.trim().isNotEmpty) {
                      final normalized = query.toLowerCase().trim();
                      final categoryLabels = homeCategories
                          .map((cat) => cat['label']!.toLowerCase())
                          .toList();

                      if (categoryLabels.contains(normalized)) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryProductsScreen(category: query),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(initialQuery: query),
                          ),
                        );
                      }
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search trusted vendors, gadgets, groceries...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8A94A6),
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF667085),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 1),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return IconButton(
                          icon: const Icon(Icons.clear, color: lightGrey),
                          onPressed: searchController.clear,
                        );
                      },
                    ),
                  ),
                  style: const TextStyle(
                    color: secondaryBlack,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: infoTop,
              child: Opacity(
                opacity: greetingOpacity,
                child: Transform.translate(
                  offset: Offset(0, panelOffset),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          getTimeBasedGreeting(userFirstName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryBlack,
                            fontSize: headingSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: 1.05,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _pharmacyShortcut(context),
                    ],
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
  double get maxExtent => 116.0;

  @override
  double get minExtent => 62.0;

  @override
  bool shouldRebuild(covariant _CollapsingSearchHeader oldDelegate) {
    return oldDelegate.userFirstName != userFirstName ||
        oldDelegate.searchController != searchController;
  }
}

// ────────────────────────────────────────────────
// OTHER WIDGETS
// ────────────────────────────────────────────────

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;

  const ShimmerLoading({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(width: width, height: height, color: Colors.white),
    );
  }
}

class ProductListHorizontal extends StatelessWidget {
  final List<Product> products;
  final String sectionKey;
  final bool showFlashBadge;
  final bool showNewBadge;

  const ProductListHorizontal({
    super.key,
    required this.products,
    required this.sectionKey,
    this.showFlashBadge = false,
    this.showNewBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ProductCard.standardCardHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          final heroTag = 'product-$sectionKey-${product.id}-$index';
          return SizedBox(
            width: 176,
            child: ProductCard(
              product: product,
              heroTag: heroTag,
              showFlashBadge: showFlashBadge,
              showNewBadge: showNewBadge,
            ),
          );
        },
      ),
    );
  }
}

class ProductListGrid extends StatelessWidget {
  final List<Product> products;
  final String sectionKey;

  const ProductListGrid({
    super.key,
    required this.products,
    required this.sectionKey,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Text(
              'No products available right now.',
              style: TextStyle(
                color: lightGrey,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.md),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          mainAxisExtent: ProductCard.standardCardHeight,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = products[index];
          final heroTag = 'product-$sectionKey-${product.id}-$index';
          return ProductCard(product: product, heroTag: heroTag);
        }, childCount: products.length),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// PRODUCT CARD – improved image loading
// ────────────────────────────────────────────────
// class ProductCard extends StatelessWidget {
//   final Product product;
//   final String heroTag;
//   final bool showFlashBadge;
//   final bool showNewBadge;

//   const ProductCard({
//     super.key,
//     required this.product,
//     required this.heroTag,
//     this.showFlashBadge = false,
//     this.showNewBadge = false,
//   });

//   String _formatPrice(double price) {
//     final formatter = NumberFormat.currency(
//       locale: 'en_NG',
//       symbol: '₦',
//       decimalDigits: 2,
//     );
//     return formatter.format(price);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);

//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (context) => ProductDetailScreen(
//               product: product,
//               heroTag: heroTag,
//             ),
//           ),
//         );
//       },
//       child: Card(
//         color: white,
//         elevation: 4,
//         shadowColor: secondaryBlack.withValues(alpha: 0.15),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Stack(
//               children: [
//                 Hero(
//                   tag: heroTag,
//                   child: ClipRRect(
//                     borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//                     child: CachedNetworkImage(
//                       imageUrl: product.imageUrls.isNotEmpty
//                           ? product.imageUrls[0]
//                           : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image',
//                       height: 120,
//                       width: double.infinity,
//                       fit: BoxFit.cover,
//                       // Improved placeholder: grey shimmer instead of spinner
//                       placeholder: (context, url) => Shimmer.fromColors(
//                         baseColor: Colors.grey[300]!,
//                         highlightColor: Colors.grey[100]!,
//                         child: Container(
//                           height: 120,
//                           color: Colors.white,
//                         ),
//                       ),
//                       // Error: show icon + grey background
//                       errorWidget: (context, url, error) => Container(
//                         height: 120,
//                         color: Colors.grey[200],
//                         child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
//                       ),
//                     ),
//                   ),
//                 ),
//                 if (showFlashBadge)
//                   Positioned(
//                     left: 8,
//                     top: 8,
//                     child: _AnimatedBadge(
//                       label: 'FLASH SALE',
//                       icon: Icons.flash_on,
//                       color: Colors.red,
//                     ),
//                   ),
//                 if (showNewBadge)
//                   Positioned(
//                     left: 8,
//                     top: 8,
//                     child: _AnimatedBadge(
//                       label: 'NEW',
//                       icon: Icons.star,
//                       color: accentGreen,
//                     ),
//                   ),
//               ],
//             ),
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       product.name,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: secondaryBlack,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           _formatPrice(product.price),
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: primaryNavy,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         // Vendor name – always visible when data is loaded
//                         Text(
//                           'Vendor: ${product.vendorBusinessName ?? 'N/A'}',
//                           style: const TextStyle(
//                             fontSize: 10,
//                             color: lightGrey,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         const SizedBox(height: 8),
//                         SizedBox(
//                           width: double.infinity,
//                           height: 36,
//                           child: ElevatedButton(
//                             onPressed: product.stockQuantity > 0
//                                 ? () {
//                                     cartProvider.addProduct(product);
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                         content: Text('${product.name} added to cart!'),
//                                         backgroundColor: accentGreen,
//                                       ),
//                                     );
//                                   }
//                                 : null,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: product.stockQuantity > 0 ? primaryNavy : Colors.grey[300],
//                               foregroundColor: product.stockQuantity > 0 ? white : Colors.grey[700],
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               padding: EdgeInsets.zero,
//                               elevation: 0,
//                             ),
//                             child: Text(
//                               product.stockQuantity > 0 ? 'Add to Cart' : 'Out of Stock',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: product.stockQuantity > 0 ? white : Colors.grey[400],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class ProductCard extends StatelessWidget {
  static const double standardCardHeight = 320;
  static const double standardImageHeight = 122;

  final Product product;
  final String heroTag;
  final bool showFlashBadge;
  final bool showNewBadge;

  const ProductCard({
    super.key,
    required this.product,
    required this.heroTag,
    this.showFlashBadge = false,
    this.showNewBadge = false,
  });

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 2,
    );
    return formatter.format(price);
  }

  String _resolvedImageUrl(Product product) {
    if (product.imageUrls.isEmpty) {
      return 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image';
    }

    final url = product.imageUrls.first;
    if (url.startsWith('http')) {
      return url;
    }

    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }

    return '$baseUrl/$url';
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final description = product.description.trim();
    final hasDescription =
        description.isNotEmpty &&
        description.toLowerCase() != product.name.trim().toLowerCase();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: primaryNavy.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    ProductDetailScreen(product: product, heroTag: heroTag),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF8FAFF)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: _resolvedImageUrl(product),
                              height: standardImageHeight,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  height: standardImageHeight,
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: standardImageHeight,
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.06),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.10),
                                      ],
                                      stops: const [0.0, 0.35, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.36),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          product.stockQuantity > 0 ? 'In stock' : 'Sold out',
                          style: TextStyle(
                            color: product.stockQuantity > 0
                                ? const Color(0xFFE9FFF1)
                                : const Color(0xFFFFE7E7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    if (showFlashBadge)
                      const Positioned(
                        left: 12,
                        top: 12,
                        child: _AnimatedBadge(
                          label: 'HOT',
                          icon: Icons.local_fire_department_rounded,
                          color: Colors.red,
                        ),
                      ),
                    if (showNewBadge)
                      const Positioned(
                        left: 12,
                        top: 12,
                        child: _AnimatedBadge(
                          label: 'NEW',
                          icon: Icons.auto_awesome_rounded,
                          color: accentGreen,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 14.2,
                            fontWeight: FontWeight.w800,
                            color: secondaryBlack,
                            height: 1.24,
                            letterSpacing: -0.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.vendorBusinessName?.isNotEmpty == true
                              ? product.vendorBusinessName!
                              : 'Vendor unavailable',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.2,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667085),
                            height: 1.25,
                          ),
                        ),
                        if (hasDescription) ...[
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.8,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475467),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        const SizedBox(height: 8),
                        Text(
                          _formatPrice(product.price),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: primaryNavy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                              animationDuration: const Duration(
                                milliseconds: 200,
                              ),
                              elevation: 0,
                              backgroundColor: product.stockQuantity > 0
                                  ? primaryNavy
                                  : Colors.grey[300],
                              foregroundColor: product.stockQuantity > 0
                                  ? white
                                  : Colors.grey[700],
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              product.stockQuantity > 0
                                  ? 'Add to Cart'
                                  : 'Out of Stock',
                              style: const TextStyle(
                                fontSize: 12.5,
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
      ),
    );
  }
}

class _AnimatedBadge extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _AnimatedBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  _AnimatedBadgeState createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<_AnimatedBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withValues(alpha: 0.90),
                  widget.color.withValues(alpha: 0.72),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 13, color: white),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _AnimatedText({required this.text, required this.style});

  @override
  State<_AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<_AnimatedText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(widget.text, style: widget.style),
    );
  }
}

// ────────────────────────────────────────────────
// CACHE HELPERS
// ────────────────────────────────────────────────
extension ProductCache on List<Product> {
  String toCacheString() {
    return jsonEncode(map((p) => p.toJson()).toList());
  }

  List<Product> fromCacheString(String? cached) {
    if (cached == null || cached.isEmpty) return [];
    try {
      final list = jsonDecode(cached) as List<dynamic>;
      return list.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Cache parse error: $e');
      return [];
    }
  }
}
