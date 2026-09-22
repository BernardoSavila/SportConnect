class AttendanceEntry {
  final int userId;
  final String userName;
  final String status; // pending | present | absent

  AttendanceEntry({required this.userId, required this.userName, required this.status});

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    return AttendanceEntry(
      userId: json['user_id'],
      userName: json['user_name'],
      status: json['status'],
    );
  }
}
