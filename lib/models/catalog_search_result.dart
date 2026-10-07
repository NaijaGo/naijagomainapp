import 'product.dart';

class CatalogSearchResult {
  const CatalogSearchResult({
    required this.products,
    required this.total,
    required this.page,
    required this.hasMore,
    this.collection,
    this.interpretation = 'catalog_attributes',
    this.externalAnswer = '',
    this.externalSources = const [],
    this.vendors = const [],
    this.externalLabel = 'External information — not a NaijaGo listing.',
  });
  final List<Product> products;
  final List<Map<String, dynamic>> vendors;
  final int total;
  final int page;
  final bool hasMore;
  final Map<String, dynamic>? collection;
  final String interpretation;
  final String externalAnswer;
  final List<Map<String, dynamic>> externalSources;
  final String externalLabel;

  factory CatalogSearchResult.fromJson(Map<String, dynamic> json) =>
      CatalogSearchResult(
        products: (json['products'] as List? ?? [])
            .whereType<Map>()
            .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        vendors: (json['vendors'] as List? ?? const []).whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row)).toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        hasMore: json['hasMore'] == true,
        interpretation: json['interpretation'] == 'gemini_intent'
            ? 'gemini_intent'
            : 'catalog_attributes',
        collection: json['collection'] is Map
            ? Map<String, dynamic>.from(json['collection'] as Map)
            : null,
        externalAnswer: json['externalAnswer']?.toString() ?? '',
        externalSources: (json['externalSources'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false),
        externalLabel: json['externalLabel']?.toString() ??
            'External information — not a NaijaGo listing.',
      );
}
