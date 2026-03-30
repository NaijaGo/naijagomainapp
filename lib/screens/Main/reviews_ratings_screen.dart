// lib/screens/Main/reviews_ratings_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../models/review.dart'; // Import the Review model
import '../../theme/app_theme.dart';
import '../../widgets/tech_glow_background.dart';
// To navigate to product details if needed

// Defined custom colors for consistency and enchantment
const Color deepNavyBlue = AppTheme.primaryNavy;
const Color greenYellow = Color(0xFFF4F8FF);
const Color whiteBackground = Colors.white;
const Color secondaryBlack = AppTheme.secondaryBlack;
const Color borderGrey = AppTheme.borderGrey;
const Color mutedText = AppTheme.mutedText;
const Color starGold = Color(0xFFFFD700); // New Gold color for stars

class ReviewsRatingsScreen extends StatefulWidget {
  const ReviewsRatingsScreen({super.key});

  @override
  State<ReviewsRatingsScreen> createState() => _ReviewsRatingsScreenState();
}

class _ReviewsRatingsScreenState extends State<ReviewsRatingsScreen> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMyReviews();
  }

  Future<void> _fetchMyReviews() async {
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
      // Assuming a backend endpoint to fetch reviews by the logged-in user
      // You might need to adjust this URL based on your actual backend implementation
      final Uri url = Uri.parse(
        '$baseUrl/api/reviews/myreviews',
      ); // Example endpoint
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> reviewsJson = jsonDecode(response.body);
        setState(() {
          _reviews = reviewsJson.map((json) => Review.fromJson(json)).toList();
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to fetch reviews.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred: $e. Check backend server and network.';
      });
      debugPrint('Error fetching reviews: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed theme color scheme reference as we're using custom constants
    // final color = Theme.of(context).colorScheme;

    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'My Reviews & Ratings',
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
                        onPressed: _fetchMyReviews,
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
            : _reviews.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'You haven\'t submitted any reviews yet. Go find something you love!',
                    style: TextStyle(
                      color: whiteBackground.withValues(alpha: 0.8),
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: const BorderSide(color: borderGrey),
                    ),
                    color: whiteBackground,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0), // Increased padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name (if available)
                          if (review.productName != null)
                            Text(
                              review.productName!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: secondaryBlack,
                              ),
                            ),
                          const SizedBox(height: 10),
                          // Rating Stars
                          Row(
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                starIndex < review.rating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: starGold, // Stars are now gold
                                size: 22,
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          // Review Comment
                          Text(
                            review.comment,
                            style: const TextStyle(
                              fontSize: 14,
                              color: secondaryBlack,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Date of Review
                          Text(
                            'Reviewed on: ${review.createdAt.toLocal().toIso8601String().split('T')[0]}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: mutedText,
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
