class FoodReadinessCampaign {
  final String mealType;
  final String title;
  final String message;
  final String imageUrl;
  final String city;
  final String startTime;
  final String endTime;
  final bool isActive;

  const FoodReadinessCampaign({
    required this.mealType,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.city,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  factory FoodReadinessCampaign.fromJson(Map<String, dynamic> json) {
    return FoodReadinessCampaign(
      mealType: json['mealType']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      isActive: json['isActive'] != false,
    );
  }

  String get cacheKey => '$city-$mealType-$startTime-$endTime';
}
