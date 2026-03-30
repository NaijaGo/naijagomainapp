// lib/screens/Main/saved_items_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tech_glow_background.dart';
import 'product_detail_screen.dart';

// Defined custom colors for consistency and enchantment
const Color deepNavyBlue = AppTheme.primaryNavy;
const Color greenYellow = Color(0xFFF4F8FF);
const Color whiteBackground = Colors.white;
const Color secondaryBlack = AppTheme.secondaryBlack;
const Color borderGrey = AppTheme.borderGrey;
const Color mutedText = AppTheme.mutedText;

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  List<Product> _savedProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSavedProducts();
  }

  Future<void> _fetchSavedProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      if (token == null) {
        setState(() {
          _errorMessage = 'You need to be logged in to view saved items.';
        });
        return;
      }

      final Uri url = Uri.parse('$baseUrl/api/auth/saved-items');
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> itemsJson = data['savedItems'];

        setState(() {
          _savedProducts = itemsJson
              .map((json) => Product.fromJson(json))
              .toList();
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage =
              responseData['message'] ?? 'Failed to load saved products.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred: $e. Check your network connection and backend server.';
      });
      debugPrint('Error fetching saved products: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed color scheme reference as we're using custom constants
    // final color = Theme.of(context).colorScheme;

    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Saved Items',
            style: TextStyle(color: greenYellow), // AppBar title green yellow
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(
            color: greenYellow,
          ), // AppBar icons green yellow
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: greenYellow))
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: greenYellow,
                        size: 50,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: whiteBackground,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchSavedProducts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepNavyBlue,
                          foregroundColor: whiteBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _savedProducts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: greenYellow.withValues(alpha: 0.72),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No saved items yet!',
                        style: const TextStyle(
                          color: whiteBackground,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Browse products and add your favorites.',
                        style: TextStyle(
                          color: whiteBackground.withValues(alpha: 0.75),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.75,
                ),
                itemCount: _savedProducts.length,
                itemBuilder: (context, index) {
                  final product = _savedProducts[index];
                  final String heroTag =
                      'saved-product-image-${product.id}-$index';

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(
                            product: product,
                            heroTag: heroTag,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: const BorderSide(color: borderGrey),
                      ),
                      color: whiteBackground,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: heroTag,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: Image.network(
                                product.imageUrls.isNotEmpty
                                    ? product.imageUrls[0]
                                    : 'https://placehold.co/200x150/CCCCCC/000000?text=No+Image',
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 120,
                                    width: double.infinity,
                                    color: Colors
                                        .grey[800], // Darker color for no image state
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(
                              12.0,
                            ), // Increased padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: secondaryBlack,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₦${product.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: deepNavyBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Vendor: ${product.vendorBusinessName ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
