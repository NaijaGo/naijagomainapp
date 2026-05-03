class HomeCarouselSlide {
  final String id;
  final String placement;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String linkUrl;
  final String actionType;
  final String actionValue;
  final int sortOrder;
  final bool isActive;

  const HomeCarouselSlide({
    required this.id,
    required this.placement,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.linkUrl,
    required this.actionType,
    required this.actionValue,
    required this.sortOrder,
    required this.isActive,
  });

  const HomeCarouselSlide.asset({
    required this.placement,
    required this.imageUrl,
    this.title = '',
    this.subtitle = '',
    this.linkUrl = '',
    this.actionType = 'none',
    this.actionValue = '',
    this.sortOrder = 0,
    this.isActive = true,
    this.id = '',
  });

  factory HomeCarouselSlide.fromJson(Map<String, dynamic> json) {
    final sortOrder = json['sortOrder'];

    return HomeCarouselSlide(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      placement: (json['placement'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      linkUrl: (json['linkUrl'] ?? '').toString(),
      actionType: (json['actionType'] ?? 'none').toString(),
      actionValue: (json['actionValue'] ?? '').toString(),
      sortOrder: sortOrder is num
          ? sortOrder.toInt()
          : int.tryParse(sortOrder?.toString() ?? '') ?? 0,
      isActive: json['isActive'] is bool
          ? json['isActive'] as bool
          : (json['isActive'] ?? 'true').toString().toLowerCase() != 'false',
    );
  }

  bool get isRemoteImage =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
}

class HomeCarouselContent {
  final List<HomeCarouselSlide> mainSlides;
  final List<HomeCarouselSlide> promoSlides;

  const HomeCarouselContent({
    required this.mainSlides,
    required this.promoSlides,
  });

  factory HomeCarouselContent.fromJson(Map<String, dynamic> json) {
    List<HomeCarouselSlide> parseSlides(dynamic rawSlides) {
      if (rawSlides is! List) {
        return const [];
      }

      return rawSlides
          .whereType<Map>()
          .map(
            (slide) =>
                HomeCarouselSlide.fromJson(Map<String, dynamic>.from(slide)),
          )
          .where((slide) => slide.imageUrl.isNotEmpty)
          .toList()
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    }

    return HomeCarouselContent(
      mainSlides: parseSlides(json['main']),
      promoSlides: parseSlides(json['promo']),
    );
  }

  const HomeCarouselContent.empty()
    : mainSlides = const [],
      promoSlides = const [];
}
