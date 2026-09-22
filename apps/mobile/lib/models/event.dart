class TeamEvent {
  final int id;
  final int teamId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String type; // training | match
  final int? maxCapacity;

  TeamEvent({
    required this.id,
    required this.teamId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.type,
    this.maxCapacity,
  });

  factory TeamEvent.fromJson(Map<String, dynamic> json) {
    return TeamEvent(
      id: json['id'],
      teamId: json['team_id'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      location: json['location'],
      type: json['type'],
      maxCapacity: json['max_capacity'],
    );
  }
}
