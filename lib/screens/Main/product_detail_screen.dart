import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../constants.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String heroTag;
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.heroTag,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isSaved = false;
  bool _isLoadingSave = false;
  dynamic _selectedSize;
  final TextEditingController _commentController = TextEditingController();
  int _userRating = 0;
  bool _isSubmittingReview = false;
  List<Product> _relatedProducts = [];
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _checkIfProductIsSaved();
    _fetchRelatedProducts();
    if (widget.product.hasSizes && widget.product.availableSizes.isNotEmpty) {
      if (widget.product.isCustomDimensions) {
        final sizeData = widget.product.sizeData;
        final customDimensions =
            sizeData?['customDimensions'] as List<dynamic>?;
        if (customDimensions != null && customDimensions.isNotEmpty) {
          _selectedSize = customDimensions.first;
        }
      } else {
        final firstSize = widget.product.availableSizes.first;
        if (firstSize is Map<String, dynamic>) {
          _selectedSize = firstSize;
        } else {
          _selectedSize = firstSize.toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getSizeShortDisplay(dynamic sizeItem) {
    if (sizeItem == null) return '';

    if (sizeItem is String) return sizeItem.trim();

    if (sizeItem is Map<String, dynamic>) {
      final dynamic labelDynamic = sizeItem['label'];
      final String label = labelDynamic?.toString() ?? '';

      if (label.isNotEmpty) {
        return label;
      }

      final length = sizeItem['length']?.toString() ?? '0';
      final width = sizeItem['width']?.toString() ?? '0';
      final height = sizeItem['height']?.toString() ?? '0';

      return '$length×$width×$height';
    }

    return sizeItem.toString().trim();
  }

  bool _areMapsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  Future<void> _checkIfProductIsSaved() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    if (token == null) return;
    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/me');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> savedItems = responseData['savedItems'] ?? [];
        setState(() {
          _isSaved = savedItems.contains(widget.product.id);
        });
      }
    } catch (e) {
      debugPrint('Error checking saved status: $e');
    }
  }

  Future<void> _fetchRelatedProducts() async {
    setState(() => _isLoadingRelated = true);
    try {
      final String encodedCategory = Uri.encodeComponent(
        widget.product.category,
      );
      final Uri url = Uri.parse(
        '$baseUrl/api/products?category=$encodedCategory',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final products = data
            .map((e) => Product.fromJson(e))
            .toList()
            .cast<Product>();
        setState(() {
          _relatedProducts = products
              .where((p) => p.id != widget.product.id)
              .toList();
          _isLoadingRelated = false;
        });
      } else {
        setState(() => _isLoadingRelated = false);
      }
    } catch (e) {
      debugPrint('Error fetching related products: $e');
      setState(() => _isLoadingRelated = false);
    }
  }

  Future<void> _toggleSaveProduct() async {
    setState(() => _isLoadingSave = true);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final String? token = prefs.getString('jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save items.')),
      );
      setState(() => _isLoadingSave = false);
      return;
    }
    try {
      final String endpoint = _isSaved
          ? '$baseUrl/api/auth/saved-items/${widget.product.id}'
          : '$baseUrl/api/auth/saved-items';
      final http.Response response = _isSaved
          ? await http.delete(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json; charset=UTF-8',
                'Authorization': 'Bearer $token',
              },
            )
          : await http.post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json; charset=UTF-8',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'productId': widget.product.id}),
            );
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _isSaved = !_isSaved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ??
                  (_isSaved ? 'Product saved!' : 'Product unsaved.'),
            ),
            backgroundColor: _isSaved ? Colors.green : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Action failed.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoadingSave = false);
      }
    }
  }

  Future<void> _submitReview() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final String? token = prefs.getString('jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }
    if (_userRating == 0 || _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating and comment.')),
      );
      return;
    }
    setState(() => _isSubmittingReview = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': widget.product.id,
          'rating': _userRating,
          'comment': _commentController.text.trim(),
        }),
      );
      final responseData = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
        setState(() {
          _commentController.clear();
          _userRating = 0;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Submission failed'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Review error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }

  void _openImageGallery(int initialIndex) {
    final allImages = widget.product.imageUrls;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (BuildContext context, int index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: NetworkImage(allImages[index]),
                      initialScale: PhotoViewComputedScale.contained,
                      heroAttributes: PhotoViewHeroAttributes(
                        tag: 'image_$index',
                      ),
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      maxScale: PhotoViewComputedScale.covered * 3.0,
                    );
                  },
                  itemCount: allImages.length,
                  loadingBuilder: (context, event) => Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: event == null
                            ? 0
                            : event.cumulativeBytesLoaded /
                                  (event.expectedTotalBytes ?? 1),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  pageController: PageController(initialPage: initialIndex),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSizeSelection() {
    if (!widget.product.hasSizes || widget.product.availableSizes.isEmpty) {
      return const SizedBox.shrink();
    }

    final isCustom = widget.product.isCustomDimensions;
    final availableSizes = widget.product.availableSizes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten, color: Color(0xFF0A2A66), size: 20),
              const SizedBox(width: 8),
              Text(
                'Select ${widget.product.sizeType}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A2A66),
                ),
              ),
              if (widget.product.sizeUnit.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.product.sizeUnit.toUpperCase(),
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[800]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          if (isCustom)
            _buildCustomDimensionsTable()
          else
            _buildStandardSizeGrid(availableSizes),

          const SizedBox(height: 16),

          if (_selectedSize != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A2A66).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF0A2A66).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF0A2A66),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Selected: ${_getSizeShortDisplay(_selectedSize)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A2A66),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStandardSizeGrid(List<dynamic> availableSizes) {
    bool hasLongSizes = availableSizes.any((size) {
      final display = _getSizeShortDisplay(size);
      return display.length > 6;
    });

    if (hasLongSizes) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: availableSizes.map((sizeItem) {
          final displaySize = _getSizeShortDisplay(sizeItem);
          final isSelected = _isSizeSelected(sizeItem);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSize = isSelected ? null : sizeItem;
              });
            },
            child: Container(
              constraints: BoxConstraints(minWidth: 70, maxWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0A2A66) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0A2A66)
                      : Colors.grey.shade400,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF0A2A66,
                          ).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  displaySize,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF0A2A66),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          );
        }).toList(),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: availableSizes.map((sizeItem) {
          final displaySize = _getSizeShortDisplay(sizeItem);
          final isSelected = _isSizeSelected(sizeItem);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSize = isSelected ? null : sizeItem;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0A2A66) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0A2A66)
                      : Colors.grey.shade400,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF0A2A66,
                          ).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displaySize,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF0A2A66),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: Colors.white, size: 18),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      );
    }
  }

  bool _isSizeSelected(dynamic sizeItem) {
    if (_selectedSize == null) return false;

    if (sizeItem is String && _selectedSize is String) {
      return sizeItem == _selectedSize;
    }

    if (sizeItem is Map<String, dynamic> &&
        _selectedSize is Map<String, dynamic>) {
      return _areMapsEqual(sizeItem, _selectedSize as Map<String, dynamic>);
    }

    return false;
  }

  Widget _buildCustomDimensionsTable() {
    final sizeData = widget.product.sizeData;
    final customDimensions = sizeData?['customDimensions'] as List<dynamic>?;

    if (customDimensions == null || customDimensions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 40,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(100),
                1: FixedColumnWidth(80),
                2: FixedColumnWidth(80),
                3: FixedColumnWidth(80),
                4: FixedColumnWidth(60),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200),
                verticalInside: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2A66).withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Variant',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2A66),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Length',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2A66),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Width',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2A66),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Height',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2A66),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Unit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2A66),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                ...customDimensions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dim = entry.value as Map<String, dynamic>;
                  final dynamic labelDynamic = dim['label'];
                  final variantLabel =
                      labelDynamic?.toString() ?? 'V${index + 1}';
                  final isSelected = _isSizeSelected(dim);

                  return TableRow(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0A2A66).withValues(alpha: 0.12)
                          : index.isEven
                          ? Colors.grey[50]
                          : Colors.white,
                    ),
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSize = isSelected ? null : dim;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF0A2A66),
                                    size: 16,
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  variantLabel,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF0A2A66)
                                        : Colors.grey[800],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          dim['length']?.toString() ?? '-',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          dim['width']?.toString() ?? '-',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          dim['height']?.toString() ?? '-',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          (dim['unit'] as String?)?.toUpperCase() ?? 'CM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blueGrey[700],
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        if (customDimensions.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Tap a row to select / deselect variant',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _addToCart(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (widget.product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product is out of stock'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (widget.product.hasSizes && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a size first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    cartProvider.addProduct(widget.product, selectedSize: _selectedSize);

    String? displaySize;
    if (_selectedSize != null) {
      if (_selectedSize is String) {
        displaySize = _selectedSize as String;
      } else if (_selectedSize is Map<String, dynamic>) {
        final dim = _selectedSize as Map<String, dynamic>;
        final dynamic labelDynamic = dim['label'];
        final String label = labelDynamic?.toString() ?? '';
        final length = dim['length']?.toString() ?? '0';
        final width = dim['width']?.toString() ?? '0';
        final height = dim['height']?.toString() ?? '0';
        final unit = (dim['unit'] as String?)?.toUpperCase() ?? 'CM';

        if (label.isNotEmpty) {
          displaySize = '$label ($length×$width×$height $unit)';
        } else {
          displaySize = '$length×$width×$height $unit';
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          displaySize != null
              ? '${widget.product.name} ($displaySize) added to cart!'
              : '${widget.product.name} added to cart!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildBottomAddToCartButton() {
    final isOutOfStock = widget.product.stockQuantity <= 0;
    final needsSizeSelection = widget.product.hasSizes && _selectedSize == null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isOutOfStock || needsSizeSelection
                    ? null
                    : () => _addToCart(context),
                icon: const Icon(Icons.shopping_cart),
                label: Text(
                  isOutOfStock
                      ? 'Out of Stock'
                      : needsSizeSelection
                      ? 'Select Size First'
                      : 'Add to Cart',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock
                      ? Colors.grey
                      : needsSizeSelection
                      ? Colors.orange
                      : const Color(0xFF0A2A66),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    final imageUrl = widget.product.imageUrls.isNotEmpty
        ? widget.product.imageUrls.first
        : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image';
    return GestureDetector(
      onTap: () => _openImageGallery(0),
      child: Hero(
        tag: widget.heroTag,
        child: Container(
          height: 350,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraImagesGallery() {
    final extraImages = widget.product.imageUrls.skip(1).toList();
    if (extraImages.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: extraImages.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final imageUrl = extraImages[index];
            return GestureDetector(
              onTap: () => _openImageGallery(index + 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 30,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 2,
    );
    return formatter.format(price);
  }

  Widget _buildPriceAndName() {
    const Color deepNavyBlue = Color(0xFF0A2A66);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.product.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: deepNavyBlue,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatPrice(widget.product.price),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.product.stockQuantity > 0 ? 'In Stock' : 'Out of Stock',
                style: TextStyle(
                  color: widget.product.stockQuantity > 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductDetails() {
    const Color deepNavyBlue = Color(0xFF0A2A66);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.category_outlined,
                  size: 20,
                  color: deepNavyBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Category: ${widget.product.category}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: deepNavyBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.store_outlined, size: 20, color: deepNavyBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sold by: ${widget.product.vendorBusinessName ?? 'Unknown Vendor'}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: deepNavyBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0A2A66),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          widget.product.description,
          style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
        ),
      ),
    );
  }

  Widget _buildRelatedProductsSection() {
    return _isLoadingRelated
        ? const Center(child: CircularProgressIndicator())
        : SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _relatedProducts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (ctx, index) {
                final related = _relatedProducts[index];
                return _buildRelatedProductCard(related);
              },
            ),
          );
  }

  Widget _buildRelatedProductCard(Product product) {
    const Color deepNavyBlue = Color(0xFF0A2A66);
    final imageUrl = product.imageUrls.isNotEmpty
        ? product.imageUrls.first
        : 'https://placehold.co/170x130/CCCCCC/000000?text=No+Image';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              heroTag: 'product_${product.id}',
            ),
          ),
        );
      },
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'product_${product.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  imageUrl,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 130,
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: deepNavyBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(product.price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: product,
                              heroTag: 'product_${product.id}',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: product.stockQuantity > 0
                            ? deepNavyBlue
                            : Colors.grey,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        product.stockQuantity > 0 ? 'Add to Cart' : 'Out',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _userRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _userRating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your thoughts on this product...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmittingReview ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 46, 188, 131),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmittingReview
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    const Color deepNavyBlue = Color(0xFF0A2A66);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: deepNavyBlue),
        title: Text(
          widget.product.name,
          style: const TextStyle(
            color: deepNavyBlue,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: _isLoadingSave
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: deepNavyBlue,
                    ),
              onPressed: _isLoadingSave ? null : _toggleSaveProduct,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAddToCartButton(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductImage(),
            _buildExtraImagesGallery(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPriceAndName(),
                  const SizedBox(height: 20),
                  if (widget.product.hasSizes) _buildSizeSelection(),
                  _buildProductDetails(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Product Description'),
                  _buildDescriptionCard(),
                  const SizedBox(height: 24),
                  if (_relatedProducts.isNotEmpty) ...[
                    _buildSectionTitle('Similar Products'),
                    _buildRelatedProductsSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Customer Reviews'),
                  _buildReviewForm(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
