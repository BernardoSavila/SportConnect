class AttendanceStats {
  final int present;
  final int absent;
  final int pending;
  final int total;
  final int percentage;

  AttendanceStats({
    required this.present,
    required this.absent,
    required this.pending,
    required this.total,
    required this.percentage,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      present: json['present'],
      absent: json['absent'],
      pending: json['pending'],
      total: json['total'],
      percentage: json['percentage'],
    );
  }
}
