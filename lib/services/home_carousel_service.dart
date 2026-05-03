import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/home_carousel_slide.dart';

class HomeCarouselService {
  Future<HomeCarouselContent> fetchHomeCarousels() async {
    final results = await Future.wait([
      fetchCarouselSlides('main').catchError((_) => <HomeCarouselSlide>[]),
      fetchCarouselSlides('promo').catchError((_) => <HomeCarouselSlide>[]),
    ]);

    if (results[0].isNotEmpty || results[1].isNotEmpty) {
      return HomeCarouselContent(
        mainSlides: results[0],
        promoSlides: results[1],
      );
    }

    final response = await http.get(Uri.parse('$baseUrl/api/carousels/home'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return HomeCarouselContent.fromJson(decoded);
      }
    }

    throw Exception('Failed to fetch home carousels: ${response.statusCode}');
  }

  Future<List<HomeCarouselSlide>> fetchCarouselSlides(String placement) async {
    final normalizedPlacement = placement.trim().toLowerCase();
    final response = await http.get(
      Uri.parse('$baseUrl/api/carousels/$normalizedPlacement'),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (slide) =>
                  HomeCarouselSlide.fromJson(Map<String, dynamic>.from(slide)),
            )
            .where((slide) => slide.imageUrl.isNotEmpty)
            .toList()
          ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      }
    }

    throw Exception(
      'Failed to fetch $normalizedPlacement carousel: ${response.statusCode}',
    );
  }
}
