class DirectMessageModel {
  final int id;
  final int senderId;
  final int recipientId;
  final String? content;
  final String? mediaUrl;
  final String type;
  final DateTime sentAt;

  DirectMessageModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    this.content,
    this.mediaUrl,
    this.type = 'text',
    required this.sentAt,
  });

  factory DirectMessageModel.fromJson(Map<String, dynamic> json) {
    return DirectMessageModel(
      id: json['id'],
      senderId: json['sender_id'],
      recipientId: json['recipient_id'],
      content: json['content'],
      mediaUrl: json['media_url'],
      type: json['type'] ?? 'text',
      sentAt: DateTime.parse(json['sent_at']),
    );
  }
}

class ConversationPreview {
  final int userId;
  final String userName;
  final String? avatarUrl;
  final String? lastMessage;
  final String lastMessageType;
  final DateTime sentAt;

  ConversationPreview({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.lastMessage,
    required this.lastMessageType,
    required this.sentAt,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      userId: json['user_id'],
      userName: json['user_name'],
      avatarUrl: json['avatar_url'],
      lastMessage: json['last_message'],
      lastMessageType: json['last_message_type'] ?? 'text',
      sentAt: DateTime.parse(json['sent_at']),
    );
  }
}
