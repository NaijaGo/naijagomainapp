// lib/screens/Vendor/my_products_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../models/product.dart'; // Import the Product model
import '../Main/product_detail_screen.dart'; // To navigate to product details
import 'add_product_screen.dart'; // To navigate to add product screen

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  List<Product> _myProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMyProducts();
  }

  Future<void> _fetchMyProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      final Uri url = Uri.parse('$baseUrl/api/products/my-products'); // Correct backend endpoint
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> productsJson = jsonDecode(response.body);
        setState(() {
          _myProducts = productsJson.map((json) => Product.fromJson(json)).toList();
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to fetch your products.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e. Check backend server and network.';
      });
      debugPrint('Error fetching my products: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Placeholder for product deletion (implement on backend first)
  Future<void> _deleteProduct(String productId) async {
    // Implement API call to delete product on backend
    // After successful deletion, re-fetch products or remove from list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete functionality coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        title: Text('My Products', style: TextStyle(color: color.onSurface)),
        backgroundColor: color.surface,
        elevation: 1,
        iconTheme: IconThemeData(color: color.onSurface),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: color.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchMyProducts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _myProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 80, color: color.secondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 20),
                          Text(
                            'You have no products listed yet.',
                            style: TextStyle(color: color.onSurface, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const AddProductScreen()),
                              );
                              _fetchMyProducts(); // Refresh list after adding product
                            },
                            icon: Icon(Icons.add_box_outlined, color: color.onPrimary),
                            label: Text('Add Your First Product', style: TextStyle(color: color.onPrimary)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _myProducts.length,
                      itemBuilder: (context, index) {
                        final product = _myProducts[index];
                        // Create a unique Hero tag for each product image
                        final String heroTag = 'my-product-image-${product.id}-$index';

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 16.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(
                                    product: product,
                                    heroTag: heroTag, // Pass the unique tag
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: heroTag, // Use the unique tag here
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        product.imageUrls.isNotEmpty
                                            ? product.imageUrls[0]
                                            : 'https://placehold.co/80x80/CCCCCC/000000?text=No+Image',
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[200],
                                            child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey[600]),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: color.secondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₦${product.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: color.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock: ${product.stockQuantity}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: product.stockQuantity > 0 ? Colors.green.shade700 : Colors.red,
                                          ),
                                        ),
                                        Text(
                                          'Sales: ${product.salesCount}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action buttons for vendor
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: color.primary),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Edit Product functionality coming soon!')),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteProduct(product.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: _myProducts.isNotEmpty || _isLoading // Show FAB even if loading or empty to allow adding first product
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AddProductScreen()),
                );
                _fetchMyProducts(); // Refresh list after adding product
              },
              label: Text('Add Product', style: TextStyle(color: color.onPrimary)),
              icon: Icon(Icons.add, color: color.onPrimary),
              backgroundColor: color.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
              elevation: 4,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

