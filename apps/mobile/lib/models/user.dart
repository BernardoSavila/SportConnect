class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // athlete | coach | admin
  final int? teamId;
  final String? avatarUrl;
  final String? position;
  final int? jerseyNumber;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.teamId,
    this.avatarUrl,
    this.position,
    this.jerseyNumber,
  });

  bool get isCoachOrAdmin => role == 'coach' || role == 'admin';
  bool get isAdmin => role == 'admin';

  AppUser copyWith({String? avatarUrl, String? name, String? position, int? jerseyNumber}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      teamId: teamId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      position: position ?? this.position,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      teamId: json['team_id'],
      avatarUrl: json['avatar_url'],
      position: json['position'],
      jerseyNumber: json['jersey_number'],
    );
  }
}
