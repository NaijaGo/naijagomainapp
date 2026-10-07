// lib/screens/Main/reviews_ratings_screen.dart

import 'package:flutter/material.dart';

import '../../widgets/visible_back_button.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../models/review.dart'; // Import the Review model
import '../../theme/app_theme.dart';
import '../../widgets/account_page_background.dart';
import '../../widgets/review_photos.dart';
import '../../services/review_service.dart';

// To navigate to product details if needed

// Defined custom colors for consistency and enchantment
const Color deepNavyBlue = AppTheme.primaryNavy;
const Color greenYellow = AppTheme.primaryNavy;
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

  Future<void> _manageReview(Review review, String action) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete review?'),
          content: const Text('This removes your review and its photos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await ReviewService().delete(review.id);
        if (mounted) await _fetchMyReviews();
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not delete this review. Please try again.'),
            ),
          );
      }
      return;
    }
    final controller = TextEditingController(text: review.comment);
    var rating = review.rating;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Edit review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: () => update(() => rating = index + 1.0),
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
                TextField(controller: controller, maxLength: 3000, maxLines: 4),
                const Text(
                  'Existing photos are retained. Changes are checked before publication.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final comment = controller.text.trim();
    controller.dispose();
    if (confirmed != true || comment.isEmpty) return;
    try {
      await ReviewService().edit(review.id, rating, comment);
      if (mounted) await _fetchMyReviews();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this review. Please try again.'),
          ),
        );
    }
  }

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
        final decodedBody = jsonDecode(response.body);
        final reviewsJson = _extractReviews(decodedBody);
        final parsedReviews = reviewsJson
            .whereType<Map>()
            .map((json) => Review.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        setState(() {
          _reviews = parsedReviews;
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to fetch reviews.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = serverConnectionHelpMessage;
      });
      debugPrint('Error fetching reviews: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> _extractReviews(dynamic decodedBody) {
    if (decodedBody is List) {
      return decodedBody;
    }

    if (decodedBody is Map<String, dynamic>) {
      final reviews = decodedBody['reviews'] ?? decodedBody['data'];
      if (reviews is List) {
        return reviews;
      }
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    // Removed theme color scheme reference as we're using custom constants
    // final color = Theme.of(context).colorScheme;

    return AccountPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const VisibleBackButton(),
          title: const Text(
            'My reviews',
            style: TextStyle(color: greenYellow), // AppBar title green yellow
          ),
          backgroundColor: const Color(0xFFF5F7FB),
          surfaceTintColor: Colors.transparent,
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
                          color: secondaryBlack,
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
                      color: mutedText,
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
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
                                fontSize: 17,
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
                              fontSize: 15,
                              color: secondaryBlack,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Date of Review
                          if (review.verifiedPurchase)
                            const Text(
                              'Verified purchase',
                              style: TextStyle(color: Colors.green),
                            ),
                          if (review.moderationStatus != 'approved')
                            Text(
                              review.moderationStatus == 'pending'
                                  ? 'Awaiting moderation'
                                  : 'Not published',
                            ),
                          ReviewPhotos(urls: review.photos),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _manageReview(review, 'edit'),
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _manageReview(review, 'delete'),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
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
