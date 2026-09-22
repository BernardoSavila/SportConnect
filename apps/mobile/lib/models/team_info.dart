class TeamInfo {
  final int id;
  final String name;
  final String? description;
  final String inviteCode;

  TeamInfo({required this.id, required this.name, this.description, required this.inviteCode});

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      inviteCode: json['invite_code'],
    );
  }
}
