class TeamMember {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;

  TeamMember({required this.id, required this.name, required this.email, required this.role, this.avatarUrl});

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      avatarUrl: json['avatar_url'],
    );
  }
}
