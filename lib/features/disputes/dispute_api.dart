import '../../core/api_client.dart';

class DisputeApi {
  final ApiClient client;
  DisputeApi(this.client);

  Future<Map<String, dynamic>> createDispute({
    required String orderId,
    String? thumbnailUrl,
    String? initialMessage,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    return client.post('/api/disputes', {
      'orderId': orderId,
      'thumbnailUrl': thumbnailUrl,
      'initialMessage': initialMessage,
      'attachments': attachments,
    });
  }

  Future<Map<String, dynamic>> listDisputes({int page = 1, int limit = 20}) async {
    return client.get('/api/disputes', query: {'page': '$page', 'limit': '$limit'});
  }
}
