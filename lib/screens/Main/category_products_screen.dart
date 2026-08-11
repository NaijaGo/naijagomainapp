import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

import '../../constants.dart'
    hide lightGrey, primaryNavy, secondaryBlack, softGrey, white;
import '../../core/performance/json_decode.dart';
import '../../models/product.dart';
import '../../services/customer_location_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/product_social_proof.dart';
import 'product_detail_screen.dart';
import 'restaurant_food_screen.dart';

const Color primaryNavy = AppTheme.primaryNavy;
const Color secondaryBlack = AppTheme.secondaryBlack;
const Color softGrey = AppTheme.softGrey;
const Color white = AppTheme.cardWhite;
const Color borderGrey = AppTheme.borderGrey;
const Color dangerRed = AppTheme.dangerRed;
const Color lightGrey = AppTheme.mutedText;

class CategoryProductsScreen extends StatefulWidget {
  final String category;
  final VoidCallback? onReturnToDashboard;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    this.onReturnToDashboard,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  double? _customerLatitude;
  double? _customerLongitude;
  double? _minimumPrice;
  double? _maximumPrice;
  double _minimumRating = 0;
  bool _inStockOnly = false;
  String _sort = 'newest';

  int get _activeFilterCount =>
      (_minimumPrice != null ? 1 : 0) +
      (_maximumPrice != null ? 1 : 0) +
      (_minimumRating > 0 ? 1 : 0) +
      (_inStockOnly ? 1 : 0) +
      (_sort != 'newest' ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _loadCustomerLocationAndProducts();
  }

  Future<void> _loadCustomerLocationAndProducts() async {
    final location = await CustomerLocationService().getSavedCustomerLocation();
    if (mounted && location != null) {
      setState(() {
        _customerLatitude = location.latitude;
        _customerLongitude = location.longitude;
      });
    }
    await _fetchFilteredProducts();
  }

  Future<void> _fetchFilteredProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isRestaurantCategory = widget.category.toLowerCase() == 'restaurant';
    final query = <String, String>{};
    if (!isRestaurantCategory) {
      query['category'] = widget.category;
    }
    if (_customerLatitude != null && _customerLongitude != null) {
      query['lat'] = _customerLatitude!.toString();
      query['lng'] = _customerLongitude!.toString();
      query['radiusKm'] = temporaryTestDeliveryRadiusKm.toStringAsFixed(0);
    }
    query['limit'] = '100';
    if (_minimumPrice != null) query['minPrice'] = _minimumPrice!.toString();
    if (_maximumPrice != null) query['maxPrice'] = _maximumPrice!.toString();
    if (_minimumRating > 0) query['minRating'] = _minimumRating.toString();
    if (_inStockOnly) query['inStock'] = 'true';
    query['sort'] = _sort;

    final endpoint = isRestaurantCategory
        ? '/api/products/restaurants'
        : '/api/products';
    final Uri url = Uri.parse(
      '$baseUrl$endpoint?${Uri(queryParameters: query).query}',
    );

    try {
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final productsJson = await decodeJsonListInBackground(response.body);
        setState(() {
          _filteredProducts = productsJson
              .map((json) => Product.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load products for this category.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please check your connection and try again.';
      });
    }
  }

  String _resolvedImageUrl(Product product) {
    if (product.imageUrls.isEmpty) {
      return 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image';
    }

    final url = product.imageUrls.first;
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }

  Future<void> _showFilters() async {
    final minimumController = TextEditingController(
      text: _minimumPrice?.toStringAsFixed(0) ?? '',
    );
    final maximumController = TextEditingController(
      text: _maximumPrice?.toStringAsFixed(0) ?? '',
    );
    var draftRating = _minimumRating;
    var draftInStock = _inStockOnly;
    var draftSort = _sort;

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter and sort',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minimumController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minimum budget',
                          prefixText: '₦ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maximumController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Maximum budget',
                          prefixText: '₦ ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: draftSort,
                  decoration: const InputDecoration(labelText: 'Sort results'),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(
                      value: 'popular',
                      child: Text('Most popular'),
                    ),
                    DropdownMenuItem(
                      value: 'best_rated',
                      child: Text('Best rated'),
                    ),
                    DropdownMenuItem(
                      value: 'price_low',
                      child: Text('Price: low to high'),
                    ),
                    DropdownMenuItem(
                      value: 'price_high',
                      child: Text('Price: high to low'),
                    ),
                  ],
                  onChanged: (value) => draftSort = value ?? 'newest',
                ),
                const SizedBox(height: 14),
                Text(
                  'Minimum rating: ${draftRating == 0 ? 'Any' : '${draftRating.toStringAsFixed(0)}+'}',
                ),
                Slider(
                  value: draftRating,
                  min: 0,
                  max: 5,
                  divisions: 5,
                  onChanged: (value) =>
                      setSheetState(() => draftRating = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('In-stock products only'),
                  value: draftInStock,
                  onChanged: (value) =>
                      setSheetState(() => draftInStock = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        minimumController.clear();
                        maximumController.clear();
                        setSheetState(() {
                          draftRating = 0;
                          draftInStock = false;
                          draftSort = 'newest';
                        });
                      },
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Apply filters'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (apply != true || !mounted) return;
    setState(() {
      _minimumPrice = double.tryParse(minimumController.text.trim());
      _maximumPrice = double.tryParse(maximumController.text.trim());
      _minimumRating = draftRating;
      _inStockOnly = draftInStock;
      _sort = draftSort;
    });
    await _fetchFilteredProducts();
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.58,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Container(
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
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                height: 130,
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
                        width: 90,
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
                        height: 38,
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 42, color: lightGrey),
                SizedBox(height: 12),
                Text(
                  'No products found in this category.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondaryBlack,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Try another category or check back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: lightGrey,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(22),
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
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: dangerRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: dangerRed,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: secondaryBlack,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _fetchFilteredProducts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryNavy,
                      foregroundColor: white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Retry',
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

  Widget _buildProductCard(Product product, int index) {
    final heroTag = 'category-${widget.category}-${product.id}-$index';
    final isRestaurantItem = product.isRestaurantItem;
    final isMedicine = product.isMedicine;
    final description = product.description.trim();
    final hasDescription =
        description.isNotEmpty &&
        description.toLowerCase() != product.name.trim().toLowerCase();
    final foodInformation = product.displayFoodInformation;
    final distanceLabel = product.distanceAndMinutesLabel(
      _customerLatitude,
      _customerLongitude,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => product.isRestaurantItem
                  ? RestaurantFoodScreen(
                      initialVendorId: product.vendorId,
                      initialVendorName: product.displayRestaurantName,
                      onReturnToDashboard: widget.onReturnToDashboard,
                    )
                  : ProductDetailScreen(product: product, heroTag: heroTag),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
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
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: _resolvedImageUrl(product),
                        height: 138,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(height: 138, color: white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 138,
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
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.04),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
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
                      const SizedBox(height: 6),
                      ProductSocialProof(product: product),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isRestaurantItem
                              ? const Color(0xFFFFF3E8)
                              : isMedicine
                              ? const Color(0xFFEAFBF9)
                              : const Color(0xFFF3F6FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isRestaurantItem || isMedicine) ...[
                              Icon(
                                isRestaurantItem
                                    ? Icons.restaurant_menu_rounded
                                    : Icons.local_pharmacy_outlined,
                                size: 12,
                                color: isRestaurantItem
                                    ? const Color(0xFF9A4B00)
                                    : const Color(0xFF08756F),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                isRestaurantItem
                                    ? product.displayRestaurantName
                                    : product.sellerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isRestaurantItem
                                      ? const Color(0xFF9A4B00)
                                      : isMedicine
                                      ? const Color(0xFF08756F)
                                      : const Color(0xFF667085),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Color(0xFF667085),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              product.displayVendorLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.8,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF667085),
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isRestaurantItem || isMedicine) ...[
                        if (distanceLabel != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_outlined,
                                size: 12,
                                color: Color(0xFF667085),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  distanceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.8,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF667085),
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      if (isRestaurantItem) ...[
                        const SizedBox(height: 10),
                        Expanded(
                          child: Text(
                            '$foodInformation\nOrder time: ${product.displayOrderWindow}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475467),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ] else if (hasDescription) ...[
                        const SizedBox(height: 10),
                        Expanded(
                          child: Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475467),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      const SizedBox(height: 10),
                      Text(
                        '₦${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryNavy,
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

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_filteredProducts.isEmpty) return _buildEmptyState();

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        mainAxisExtent: 352,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product, index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softGrey,
      appBar: AppBar(
        backgroundColor: white,
        foregroundColor: secondaryBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category,
              style: const TextStyle(
                color: secondaryBlack,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const Text(
              'Category products',
              style: TextStyle(
                color: lightGrey,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Filter and sort',
                onPressed: _showFilters,
                icon: const Icon(Icons.tune_rounded),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: dangerRed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(
                        color: white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderGrey.withValues(alpha: 0.7)),
        ),
      ),
      body: _buildBody(),
    );
  }
}
