import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/catalog_category.dart';

class CatalogCategoryService {
  static const cacheKey = 'naijago.catalog-taxonomy.v1';
  static CatalogHierarchy? _bundledHierarchy;

  /// Immediately presents the bundled hierarchy, then checks the read-only API.
  /// Cache/fallback responses can never enable database reference writes.
  static Future<CatalogHierarchy> load({
    http.Client? client,
    Future<String> Function()? assetLoader,
    void Function(CatalogHierarchy)? onReady,
  }) async {
    CatalogHierarchy decode(String value) => CatalogHierarchy.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
    final bundled = assetLoader == null && _bundledHierarchy != null
        ? _bundledHierarchy!
        : decode(
            await (assetLoader?.call() ??
                rootBundle.loadString('assets/catalog_taxonomy.v1.json')),
          ).withoutReferenceWrites();
    if (assetLoader == null) _bundledHierarchy = bundled;
    onReady?.call(bundled);
    final ownedClient = client == null;
    final requests = client ?? http.Client();
    try {
      final response = await requests
          .get(Uri.parse('$baseUrl/api/categories'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return bundled;
      final hierarchy = decode(response.body);
      if (hierarchy.checksum != bundled.checksum) return bundled;
      onReady?.call(hierarchy);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          cacheKey,
          jsonEncode(hierarchy.withoutReferenceWrites().toJson()),
        );
      } catch (_) {
        /* Storage failure must not block browsing or product forms. */
      }
      return hierarchy;
    } catch (_) {
      return bundled;
    } finally {
      if (ownedClient) requests.close();
    }
  }
}
