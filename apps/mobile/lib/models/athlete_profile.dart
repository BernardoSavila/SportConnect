class AchievementEntry {
  final int id;
  final String type;
  final int points;
  final DateTime awardedAt;

  AchievementEntry({required this.id, required this.type, required this.points, required this.awardedAt});

  factory AchievementEntry.fromJson(Map<String, dynamic> json) {
    return AchievementEntry(
      id: json['id'],
      type: json['type'],
      points: json['points'],
      awardedAt: DateTime.parse(json['awarded_at']),
    );
  }
}

class AthleteProfile {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? teamId;
  final String? avatarUrl;
  final List<AchievementEntry> achievements;
  final int totalPoints;
  final String? guardianName;
  final String? guardianPhone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  AthleteProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.teamId,
    this.avatarUrl,
    required this.achievements,
    required this.totalPoints,
    this.guardianName,
    this.guardianPhone,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory AthleteProfile.fromJson(Map<String, dynamic> json) {
    return AthleteProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      teamId: json['team_id'],
      avatarUrl: json['avatar_url'],
      achievements: (json['achievements'] as List).map((e) => AchievementEntry.fromJson(e)).toList(),
      totalPoints: json['total_points'],
      guardianName: json['guardian_name'],
      guardianPhone: json['guardian_phone'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
    );
  }
}
