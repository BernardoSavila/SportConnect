class ChatMessageModel {
  final int id;
  final int teamId;
  final int senderId;
  final String? content;
  final String? mediaUrl;
  final String type; // text | image | audio
  final DateTime sentAt;

  ChatMessageModel({
    required this.id,
    required this.teamId,
    required this.senderId,
    this.content,
    this.mediaUrl,
    this.type = 'text',
    required this.sentAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      teamId: json['team_id'],
      senderId: json['sender_id'],
      content: json['content'],
      mediaUrl: json['media_url'],
      type: json['type'] ?? 'text',
      sentAt: DateTime.parse(json['sent_at']),
    );
  }
}
