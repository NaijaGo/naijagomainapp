import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/food_readiness_campaign.dart';

class FoodReadinessCampaignService {
  const FoodReadinessCampaignService();

  Future<FoodReadinessCampaign?> fetchActiveCampaign({String? city}) async {
    final query = <String, String>{};
    if (city != null && city.trim().isNotEmpty) {
      query['city'] = city.trim();
    }
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final response = await http.get(
      Uri.parse('$baseUrl/api/food-readiness-campaigns/active$suffix'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load food readiness campaign.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['campaign'] == null) return null;
    return FoodReadinessCampaign.fromJson(
      Map<String, dynamic>.from(decoded['campaign'] as Map),
    );
  }
}
