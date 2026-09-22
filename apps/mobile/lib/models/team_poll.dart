class PollOptionResult {
  final int id;
  final String text;
  final int votes;

  PollOptionResult({required this.id, required this.text, required this.votes});

  factory PollOptionResult.fromJson(Map<String, dynamic> json) {
    return PollOptionResult(id: json['id'], text: json['text'], votes: json['votes']);
  }
}

class TeamPoll {
  final int id;
  final int teamId;
  final String question;
  final int createdBy;
  final DateTime createdAt;
  final List<PollOptionResult> options;
  final int? myVote;

  TeamPoll({
    required this.id,
    required this.teamId,
    required this.question,
    required this.createdBy,
    required this.createdAt,
    required this.options,
    this.myVote,
  });

  int get totalVotes => options.fold(0, (sum, o) => sum + o.votes);

  factory TeamPoll.fromJson(Map<String, dynamic> json) {
    return TeamPoll(
      id: json['id'],
      teamId: json['team_id'],
      question: json['question'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      options: (json['options'] as List).map((e) => PollOptionResult.fromJson(e)).toList(),
      myVote: json['my_vote'],
    );
  }
}
