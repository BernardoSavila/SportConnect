class RankingEntry {
  final int userId;
  final String name;
  final int totalPoints;

  RankingEntry({required this.userId, required this.name, required this.totalPoints});

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      userId: json['user_id'],
      name: json['name'],
      totalPoints: json['total_points'],
    );
  }
}
