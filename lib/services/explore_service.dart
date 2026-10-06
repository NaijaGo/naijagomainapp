import 'dart:convert';
import 'package:naija_go/models/explore_video.dart';
import 'package:naija_go/services/api_service.dart';

class ExploreService {
  Future<ExploreFeedPage> fetchFeedPage({int page = 1, int limit = 10}) async {
    final response = await ApiService.get('/api/explore?page=$page&limit=$limit');
    final body = _decode(response);
    final items = body['items'];
    if (items is! List) throw Exception('Explore feed response is invalid.');
    return ExploreFeedPage(
      items: items.whereType<Map>().map((item) => ExploreVideo.fromJson(Map<String, dynamic>.from(item))).toList(),
      page: (body['page'] as num?)?.toInt() ?? page,
      hasMore: body['hasMore'] == true,
    );
  }

  Future<List<ExploreVideo>> fetchFeed({int page = 1, int limit = 10}) async {
    return (await fetchFeedPage(page: page, limit: limit)).items;
  }

  Future<List<Map<String, dynamic>>> fetchComments(String videoId, {int page = 1, int limit = 20}) async {
    return (await fetchCommentsPage(videoId, page: page, limit: limit)).items;
  }

  Future<ExploreCommentsPage> fetchCommentsPage(String videoId, {int page = 1, int limit = 20}) async {
    final response = await ApiService.get('/api/explore/$videoId/comments?page=$page&limit=$limit');
    final body = _decode(response);
    final items = body['items'];
    if (items is! List) throw Exception('Comments response is invalid.');
    return ExploreCommentsPage(
      items: items.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(),
      page: (body['page'] as num?)?.toInt() ?? page,
      total: (body['total'] as num?)?.toInt() ?? items.length,
      hasMore: body['hasMore'] == true,
    );
  }

  Future<Map<String, dynamic>> addComment(String videoId, String text) async {
    final response = await ApiService.post('/api/explore/$videoId/comments', {'text': text});
    return _decode(response);
  }

  Future<int> like(String videoId) async {
    final response = await ApiService.put('/api/explore/$videoId/like', const {});
    return (_decode(response)['likesCount'] as num).toInt();
  }

  Future<int> unlike(String videoId) async {
    final response = await ApiService.delete('/api/explore/$videoId/like');
    return (_decode(response)['likesCount'] as num).toInt();
  }

  Future<ExploreVideo> publishVideo({required String filePath, required String caption, String? productId}) async {
    final response = await ApiService.uploadMultipart(
      '/api/explore/videos',
      filePath: filePath,
      fieldName: 'video',
      fields: {'caption': caption, if (productId != null) 'productId': productId},
    );
    final video = _decode(response)['video'];
    if (video is! Map) throw Exception('Published video response is invalid.');
    return ExploreVideo.fromJson(Map<String, dynamic>.from(video));
  }

  Future<Map<String, dynamic>> deleteComment(String videoId, String commentId) async {
    return _decode(await ApiService.delete('/api/explore/$videoId/comments/$commentId'));
  }

  Future<void> deleteVideo(String videoId) async {
    _decode(await ApiService.delete('/api/explore/$videoId'));
  }

  Map<String, dynamic> _decode(dynamic response) {
    final statusCode = response.statusCode as int;
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body as String);
    } catch (_) {
      throw Exception('Explore request failed ($statusCode).');
    }
    if (statusCode < 200 || statusCode >= 300) {
      final message = decoded is Map ? decoded['message'] : null;
      throw Exception(message?.toString() ?? 'Explore request failed ($statusCode).');
    }
    if (decoded is! Map) throw Exception('Explore response is invalid.');
    return Map<String, dynamic>.from(decoded);
  }
}

class ExploreFeedPage {
  const ExploreFeedPage({required this.items, required this.page, required this.hasMore});
  final List<ExploreVideo> items;
  final int page;
  final bool hasMore;
}

class ExploreCommentsPage {
  const ExploreCommentsPage({required this.items, required this.page, required this.total, required this.hasMore});
  final List<Map<String, dynamic>> items;
  final int page;
  final int total;
  final bool hasMore;
}
