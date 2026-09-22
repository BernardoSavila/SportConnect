class FeedPost {
  final int id;
  final int teamId;
  final int authorId;
  final String content;
  final String? mediaUrl;
  final DateTime createdAt;
  final int likesCount;
  final bool likedByMe;
  final bool isOfficial;

  FeedPost({
    required this.id,
    required this.teamId,
    required this.authorId,
    required this.content,
    this.mediaUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.likedByMe = false,
    this.isOfficial = false,
  });

  FeedPost copyWith({int? likesCount, bool? likedByMe}) {
    return FeedPost(
      id: id,
      teamId: teamId,
      authorId: authorId,
      content: content,
      mediaUrl: mediaUrl,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      likedByMe: likedByMe ?? this.likedByMe,
      isOfficial: isOfficial,
    );
  }

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'],
      teamId: json['team_id'],
      authorId: json['author_id'],
      content: json['content'],
      mediaUrl: json['media_url'],
      createdAt: DateTime.parse(json['created_at']),
      likesCount: json['likes_count'] ?? 0,
      likedByMe: json['liked_by_me'] ?? false,
      isOfficial: json['is_official'] ?? false,
    );
  }
}
