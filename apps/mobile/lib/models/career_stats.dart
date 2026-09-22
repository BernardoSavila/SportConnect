class CareerStats {
  final int goals;
  final int assists;
  final int minutesPlayed;
  final int games;

  CareerStats({required this.goals, required this.assists, required this.minutesPlayed, required this.games});

  factory CareerStats.fromJson(Map<String, dynamic> json) {
    return CareerStats(
      goals: json['goals'],
      assists: json['assists'],
      minutesPlayed: json['minutes_played'],
      games: json['games'],
    );
  }
}
