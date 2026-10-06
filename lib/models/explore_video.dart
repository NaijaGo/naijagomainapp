import 'package:flutter/material.dart';

class ExploreVideo {
  const ExploreVideo({
    required this.id,
    required this.videoUrl,
    required this.creatorName,
    required this.caption,
    this.posterUrl,
    this.creatorAvatarUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.productId,
    this.productName,
    this.shareUrl,
  });

  final String id;
  final String videoUrl;
  final String creatorName;
  final String caption;
  final String? posterUrl;
  final String? creatorAvatarUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final String? productId;
  final String? productName;
  final String? shareUrl;

  factory ExploreVideo.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] is Map ? Map<String, dynamic>.from(json['creator']) : <String, dynamic>{};
    final product = json['product'] is Map ? Map<String, dynamic>.from(json['product']) : <String, dynamic>{};
    return ExploreVideo(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      videoUrl: (json['videoUrl'] ?? '').toString(),
      creatorName: (creator['name'] ?? 'NaijaGo creator').toString(),
      caption: (json['caption'] ?? '').toString(),
      posterUrl: (json['thumbnailUrl'] ?? json['posterUrl'])?.toString(),
      creatorAvatarUrl: creator['avatarUrl']?.toString(),
      likeCount: _asInt(json['likesCount'] ?? json['likeCount']),
      commentCount: _asInt(json['commentsCount'] ?? json['commentCount']),
      isLiked: json['isLiked'] == true,
      productId: product['id']?.toString(),
      productName: product['name']?.toString(),
      shareUrl: json['shareUrl']?.toString(),
    );
  }

  ExploreVideo copyWith({bool? isLiked, int? likeCount, int? commentCount}) => ExploreVideo(
    id: id, videoUrl: videoUrl, creatorName: creatorName, caption: caption,
    posterUrl: posterUrl, creatorAvatarUrl: creatorAvatarUrl,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    isLiked: isLiked ?? this.isLiked,
    productId: productId, productName: productName, shareUrl: shareUrl,
  );

  static int _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
