// lib/screens/Main/write_review_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../models/product.dart'; // Import Product model to get product details
import '../../widgets/tech_glow_background.dart';

class WriteReviewScreen extends StatefulWidget {
  final Product product; // The product for which the review is being written

  const WriteReviewScreen({super.key, required this.product});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _commentController = TextEditingController();
  double _rating = 0.0; // User's selected rating (0 to 5)
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _setRating(double rating) {
    setState(() {
      _rating = rating;
    });
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate() || _rating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating and a comment.')),
      );
      return;
    }

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
      final Uri url = Uri.parse(
        '$baseUrl/api/reviews',
      ); // Backend endpoint for submitting reviews
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': widget.product.id,
          'rating': _rating,
          'comment': _commentController.text.trim(),
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 201) {
        // 201 Created is typical for successful POST
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ?? 'Review submitted successfully!',
            ),
          ),
        );
        if (mounted) {
          Navigator.of(context).pop(true); // Pop with true to indicate success
        }
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to submit review.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred: $e. Check backend server and network.';
      });
      debugPrint('Error submitting review: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Write a Review',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading && _errorMessage == null
            ? Center(child: CircularProgressIndicator(color: color.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: color.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reviewing Product:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.product.imageUrls.isNotEmpty
                                  ? widget.product.imageUrls[0]
                                  : 'https://placehold.co/60x60/CCCCCC/000000?text=No+Image',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            widget.product.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: color.secondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '₦${widget.product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: color.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(height: 30, thickness: 1),

                        Text(
                          'Your Rating:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color.secondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(
                                  index < _rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 40,
                                ),
                                onPressed: () => _setRating(index + 1.0),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Your Comment:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color.secondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _commentController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText:
                                'Share your experience with this product...',
                            hintStyle: TextStyle(
                              color: color.secondary.withValues(alpha: 0.5),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: color.secondary.withValues(alpha: 0.5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: color.primary,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: color.secondary.withValues(alpha: 0.3),
                              ),
                            ),
                            filled: true,
                            fillColor: color.surface,
                          ),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter your comment'
                              : null,
                        ),
                        const SizedBox(height: 24),

                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        SizedBox(
                          width: double.infinity,
                          child: _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: color.primary,
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _submitReview,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: color.primary,
                                    foregroundColor: color.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Submit Review',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
