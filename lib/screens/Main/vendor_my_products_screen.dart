import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../widgets/vendor_ui.dart';

class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final double averageRating;
  final List<String> imageUrls;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.averageRating,
    required this.imageUrls,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'].toString(),
      name: (json['name'] ?? 'Unnamed Product').toString(),
      category: (json['category'] ?? 'Uncategorized').toString(),
      price: double.tryParse('${json['price'] ?? 0}') ?? 0,
      averageRating: double.tryParse('${json['averageRating'] ?? 0}') ?? 0,
      imageUrls: List<String>.from(json['imageUrls'] ?? const []),
    );
  }
}

class VendorMyProductsScreen extends StatefulWidget {
  const VendorMyProductsScreen({super.key});

  @override
  State<VendorMyProductsScreen> createState() => _VendorMyProductsScreenState();
}

class _VendorMyProductsScreenState extends State<VendorMyProductsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _fetchVendorProducts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _fetchVendorProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/products/myproducts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> productsData = json.decode(response.body);
        setState(() {
          _products = productsData
              .map((data) => Product.fromJson(data as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to load products');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showComingSoonDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VendorUi.whiteBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: VendorUi.border),
        ),
        title: const Text(
          'Use the seller dashboard',
          style: TextStyle(
            color: VendorUi.deepNavyBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Product creation and editing live inside the seller dashboard flow so your catalogue and metrics stay aligned.',
          style: TextStyle(color: VendorUi.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: VendorUi.deepNavyBlue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: VendorUi.whiteBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: VendorUi.border),
            ),
            title: const Text(
              'Delete this product?',
              style: TextStyle(color: VendorUi.deepNavyBlue),
            ),
            content: const Text(
              'This removes the item from your storefront and cannot be undone.',
              style: TextStyle(color: VendorUi.textMuted, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: VendorUi.deepNavyBlue),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: VendorUi.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/products/$productId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _products.removeWhere((product) => product.id == productId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully.')),
          );
        }
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to delete product');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VendorUi.theme,
      child: Scaffold(
        backgroundColor: VendorUi.surface,
        appBar: AppBar(
          title: const Text('My Products'),
          actions: [
            IconButton(
              onPressed: _fetchVendorProducts,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh catalogue',
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showComingSoonDialog,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Add Product'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final totalValue = _products.fold<double>(
      0,
      (sum, product) => sum + product.price,
    );
    final ratedProducts =
        _products.where((product) => product.averageRating > 0).length;

    return RefreshIndicator(
      onRefresh: _fetchVendorProducts,
      color: VendorUi.deepNavyBlue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          VendorPageHero(
            badge: 'Catalogue management',
            title: 'My products',
            subtitle:
                'Track listing performance, review your category spread, and keep the storefront polished from one seller workspace.',
            icon: Icons.inventory_2_outlined,
            stats: [
              VendorHeroStat(
                label: 'Active listings',
                value: '${_products.length}',
              ),
              VendorHeroStat(
                label: 'Rated products',
                value: '$ratedProducts',
              ),
              VendorHeroStat(
                label: 'Catalogue value',
                value: '₦${totalValue.toStringAsFixed(0)}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const VendorPanel(
              title: 'Loading catalogue',
              subtitle: 'We are syncing your latest products and performance data.',
              child: SizedBox(
                height: 96,
                child: Center(
                  child: CircularProgressIndicator(
                    color: VendorUi.deepNavyBlue,
                  ),
                ),
              ),
            )
          else if (_error != null)
            VendorPanel(
              title: 'Couldn’t load products',
              subtitle: 'The seller catalogue could not be reached right now.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: VendorUi.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _fetchVendorProducts,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            )
          else if (_products.isEmpty)
            VendorPanel(
              title: 'No products yet',
              subtitle:
                  'Your catalogue is still empty. Once you publish an item, it will appear here with its performance snapshot.',
              child: Column(
                children: [
                  _buildNoProductsAnimation(),
                  const SizedBox(height: 12),
                  const Text(
                    "You haven't added a product yet.",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: VendorUi.deepNavyBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the add product action to publish your first listing.',
                    style: TextStyle(
                      color: VendorUi.textMuted,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            _buildAnalyticsCard(),
            const SizedBox(height: 20),
            _buildProductRatingsBarChart(),
            const SizedBox(height: 20),
            VendorPanel(
              title: 'Your listings',
              subtitle:
                  'Review pricing, ratings, and quick actions for each live product.',
              child: Column(
                children: [
                  for (var i = 0; i < _products.length; i++) ...[
                    _buildProductTile(_products[i]),
                    if (i != _products.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSuggestionsSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildNoProductsAnimation() {
    try {
      return Lottie.asset(
        'assets/animations/no-product.json',
        width: 200,
        height: 200,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
      );
    } catch (_) {
      return _buildFallbackIcon();
    }
  }

  Widget _buildFallbackIcon() {
    return Column(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 100,
          color: VendorUi.deepNavyBlue.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 20),
        RotationTransition(
          turns: _animationController,
          child: const Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: VendorUi.greenYellow,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard() {
    final Map<String, int> categoryCounts = {};
    for (final product in _products) {
      categoryCounts[product.category] = (categoryCounts[product.category] ?? 0) + 1;
    }

    const palette = <Color>[
      VendorUi.deepNavyBlue,
      VendorUi.blue,
      VendorUi.success,
      VendorUi.warning,
      Color(0xFF4F6BCF),
    ];

    final entries = categoryCounts.entries.toList();
    final sections = entries.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      return PieChartSectionData(
        value: value.value.toDouble(),
        title: '${value.key}\n(${value.value})',
        color: palette[index % palette.length],
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: VendorUi.whiteBackground,
        ),
      );
    }).toList();

    return VendorPanel(
      title: 'Catalogue mix',
      subtitle: 'See how your listings are spread across categories.',
      child: SizedBox(
        height: 220,
        child: PieChart(
          PieChartData(
            sections: sections,
            sectionsSpace: 4,
            centerSpaceRadius: 42,
          ),
        ),
      ),
    );
  }

  Widget _buildProductRatingsBarChart() {
    final Map<String, int> ratingCounts = {
      '0.0': 0,
      '1.0-1.9': 0,
      '2.0-2.9': 0,
      '3.0-3.9': 0,
      '4.0-4.9': 0,
      '5.0': 0,
    };

    for (final product in _products) {
      if (product.averageRating == 0.0) {
        ratingCounts['0.0'] = (ratingCounts['0.0'] ?? 0) + 1;
      } else if (product.averageRating < 2.0) {
        ratingCounts['1.0-1.9'] = (ratingCounts['1.0-1.9'] ?? 0) + 1;
      } else if (product.averageRating < 3.0) {
        ratingCounts['2.0-2.9'] = (ratingCounts['2.0-2.9'] ?? 0) + 1;
      } else if (product.averageRating < 4.0) {
        ratingCounts['3.0-3.9'] = (ratingCounts['3.0-3.9'] ?? 0) + 1;
      } else if (product.averageRating < 5.0) {
        ratingCounts['4.0-4.9'] = (ratingCounts['4.0-4.9'] ?? 0) + 1;
      } else {
        ratingCounts['5.0'] = (ratingCounts['5.0'] ?? 0) + 1;
      }
    }

    final barGroups = ratingCounts.entries.toList().asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.value.toDouble(),
            color: VendorUi.deepNavyBlue,
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();

    return VendorPanel(
      title: 'Ratings snapshot',
      subtitle: 'Understand how your catalogue is performing across review bands.',
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < ratingCounts.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          ratingCounts.keys.elementAt(index),
                          style: const TextStyle(
                            color: VendorUi.deepNavyBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() == value) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: VendorUi.deepNavyBlue,
                          fontSize: 12,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: VendorUi.deepNavyBlue.withValues(alpha: 0.14),
                  strokeWidth: 1,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return VendorPanel(
      title: 'Store growth ideas',
      subtitle: 'Small improvements here can lift conversion and repeat trust.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipCard(
            icon: Icons.lightbulb_outline,
            text: 'Add more product photos so buyers can judge quality faster.',
          ),
          _buildTipCard(
            icon: Icons.star_outline,
            text: 'Encourage customers to leave reviews after delivery.',
          ),
          _buildTipCard(
            icon: Icons.check_circle_outline,
            text: 'Keep product quality consistent to protect your ratings.',
          ),
          _buildTipCard(
            icon: Icons.description_outlined,
            text: 'Write clearer descriptions so shoppers know what to expect.',
          ),
          _buildTipCard(
            icon: Icons.support_agent,
            text: 'Responsive support reduces cancellations and refund requests.',
          ),
          const SizedBox(height: 20),
          const Text(
            'Why stronger ratings matter',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: VendorUi.deepNavyBlue,
            ),
          ),
          const SizedBox(height: 8),
          _buildBenefitText('Higher ratings increase buyer trust and confidence.'),
          _buildBenefitText('Better perception improves repeat purchase chances.'),
          _buildBenefitText('Top-rated products tend to rank better in discovery.'),
          _buildBenefitText('Stronger reviews sharpen your seller reputation overall.'),
          const SizedBox(height: 20),
          _buildAnimatedBoostButton(),
        ],
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VendorUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VendorUi.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: VendorUi.deepNavyBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: VendorUi.deepNavyBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: VendorUi.deepNavyBlue,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: VendorUi.success, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: VendorUi.deepNavyBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBoostButton() {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.03).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showComingSoonDialog,
          icon: const Icon(Icons.trending_up_rounded),
          label: const Text('Boost Product Visibility'),
        ),
      ),
    );
  }

  Widget _buildProductTile(Product product) {
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls[0] : null;

    return Container(
      decoration: VendorUi.panelDecoration(
        color: VendorUi.whiteBackground,
        radius: 20,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 64,
            height: 64,
            color: VendorUi.surface,
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        color: VendorUi.deepNavyBlue,
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.shopping_bag_outlined,
                      color: VendorUi.deepNavyBlue,
                    ),
                  )
                : const Icon(
                    Icons.shopping_bag_outlined,
                    color: VendorUi.deepNavyBlue,
                  ),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: VendorUi.deepNavyBlue,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: VendorUi.deepNavyBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      product.category,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VendorUi.deepNavyBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₦${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: VendorUi.deepNavyBlue,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: VendorUi.warning,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  product.averageRating.toStringAsFixed(1),
                  style: const TextStyle(color: VendorUi.textMuted),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: VendorUi.deepNavyBlue),
          onSelected: (value) {
            if (value == 'edit') {
              _showComingSoonDialog();
            } else if (value == 'delete') {
              _deleteProduct(product.id);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text(
                'Edit',
                style: TextStyle(color: VendorUi.deepNavyBlue),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete',
                style: TextStyle(color: VendorUi.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
