class CoachProfile {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime? coachStartedAt;
  final String? coachPhone;
  final String? coachCertification;
  final String? coachNotes;

  CoachProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.coachStartedAt,
    this.coachPhone,
    this.coachCertification,
    this.coachNotes,
  });

  factory CoachProfile.fromJson(Map<String, dynamic> json) {
    return CoachProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      coachStartedAt: json['coach_started_at'] != null ? DateTime.tryParse(json['coach_started_at']) : null,
      coachPhone: json['coach_phone'],
      coachCertification: json['coach_certification'],
      coachNotes: json['coach_notes'],
    );
  }
}

class AdminTeamProfile {
  final int id;
  final String name;
  final String? description;
  final String inviteCode;
  final DateTime? foundedAt;
  final String? ageGroup;
  final String? modality;
  final String? homeVenue;
  final DateTime? seasonStartedAt;
  final int memberCount;
  final CoachProfile? coach;
  final List<CoachProfile> assistantCoaches;

  AdminTeamProfile({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    this.foundedAt,
    this.ageGroup,
    this.modality,
    this.homeVenue,
    this.seasonStartedAt,
    required this.memberCount,
    this.coach,
    this.assistantCoaches = const [],
  });

  factory AdminTeamProfile.fromJson(Map<String, dynamic> json) {
    return AdminTeamProfile(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      inviteCode: json['invite_code'],
      foundedAt: json['founded_at'] != null ? DateTime.tryParse(json['founded_at']) : null,
      ageGroup: json['age_group'],
      modality: json['modality'],
      homeVenue: json['home_venue'],
      seasonStartedAt: json['season_started_at'] != null ? DateTime.tryParse(json['season_started_at']) : null,
      memberCount: json['member_count'] ?? 0,
      coach: json['coach'] != null ? CoachProfile.fromJson(json['coach']) : null,
      assistantCoaches: (json['assistant_coaches'] as List<dynamic>? ?? [])
          .map((e) => CoachProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CoachHistoryEntry {
  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final bool current;
  final int userId;
  final String userName;

  CoachHistoryEntry({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.notes,
    required this.current,
    required this.userId,
    required this.userName,
  });

  factory CoachHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CoachHistoryEntry(
      id: json['id'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at']) : null,
      notes: json['notes'],
      current: json['current'] == true,
      userId: json['user']?['id'] ?? 0,
      userName: json['user']?['name'] ?? 'Utilizador removido',
    );
  }
}

class AdminStats {
  final int memberCount;
  final int totalEvents;
  final int upcomingEvents;
  final int pastEvents;
  final int attendanceRate;
  final int postCount;
  final int pollCount;
  final int totalPointsAwarded;

  AdminStats({
    required this.memberCount,
    required this.totalEvents,
    required this.upcomingEvents,
    required this.pastEvents,
    required this.attendanceRate,
    required this.postCount,
    required this.pollCount,
    required this.totalPointsAwarded,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      memberCount: json['member_count'] ?? 0,
      totalEvents: json['total_events'] ?? 0,
      upcomingEvents: json['upcoming_events'] ?? 0,
      pastEvents: json['past_events'] ?? 0,
      attendanceRate: json['attendance_rate'] ?? 0,
      postCount: json['post_count'] ?? 0,
      pollCount: json['poll_count'] ?? 0,
      totalPointsAwarded: json['total_points_awarded'] ?? 0,
    );
  }
}

class RosterEntry {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? position;
  final int? jerseyNumber;
  final int? attendanceRate;
  final int presentCount;
  final int totalDecided;
  final int points;
  final int achievementsCount;
  final int gamesPlayed;
  final int goals;
  final int assists;
  final int minutesPlayed;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? guardianName;
  final String? guardianPhone;

  RosterEntry({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.position,
    this.jerseyNumber,
    this.attendanceRate,
    required this.presentCount,
    required this.totalDecided,
    required this.points,
    required this.achievementsCount,
    required this.gamesPlayed,
    required this.goals,
    required this.assists,
    required this.minutesPlayed,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.guardianName,
    this.guardianPhone,
  });

  factory RosterEntry.fromJson(Map<String, dynamic> json) {
    return RosterEntry(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      position: json['position'],
      jerseyNumber: json['jersey_number'],
      attendanceRate: json['attendance_rate'],
      presentCount: json['present_count'] ?? 0,
      totalDecided: json['total_decided'] ?? 0,
      points: json['points'] ?? 0,
      achievementsCount: json['achievements_count'] ?? 0,
      gamesPlayed: json['games_played'] ?? 0,
      goals: json['goals'] ?? 0,
      assists: json['assists'] ?? 0,
      minutesPlayed: json['minutes_played'] ?? 0,
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      guardianName: json['guardian_name'],
      guardianPhone: json['guardian_phone'],
    );
  }
}

class CoachActivityStats {
  final int coachId;
  final int? tenureDays;
  final int eventsCreatedTotal;
  final int trainingsCreated;
  final int matchesCreated;
  final int? attendanceRateOwnEvents;
  final int postsPublished;
  final int pollsCreated;

  CoachActivityStats({
    required this.coachId,
    this.tenureDays,
    required this.eventsCreatedTotal,
    required this.trainingsCreated,
    required this.matchesCreated,
    this.attendanceRateOwnEvents,
    required this.postsPublished,
    required this.pollsCreated,
  });

  factory CoachActivityStats.fromJson(Map<String, dynamic> json) {
    return CoachActivityStats(
      coachId: json['coach_id'],
      tenureDays: json['tenure_days'],
      eventsCreatedTotal: json['events_created_total'] ?? 0,
      trainingsCreated: json['trainings_created'] ?? 0,
      matchesCreated: json['matches_created'] ?? 0,
      attendanceRateOwnEvents: json['attendance_rate_own_events'],
      postsPublished: json['posts_published'] ?? 0,
      pollsCreated: json['polls_created'] ?? 0,
    );
  }
}

class MembershipEntry {
  final int id;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? notes;
  final bool current;
  final int userId;
  final String userName;

  MembershipEntry({
    required this.id,
    required this.joinedAt,
    this.leftAt,
    this.notes,
    required this.current,
    required this.userId,
    required this.userName,
  });

  factory MembershipEntry.fromJson(Map<String, dynamic> json) {
    return MembershipEntry(
      id: json['id'],
      joinedAt: DateTime.parse(json['joined_at']),
      leftAt: json['left_at'] != null ? DateTime.tryParse(json['left_at']) : null,
      notes: json['notes'],
      current: json['current'] == true,
      userId: json['user']?['id'] ?? 0,
      userName: json['user']?['name'] ?? 'Utilizador removido',
    );
  }
}

class SeasonPeriod {
  final String coachName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool current;
  final int eventsTotal;
  final int trainings;
  final int matches;
  final int? attendanceRate;
  final int pointsAwarded;

  SeasonPeriod({
    required this.coachName,
    required this.startedAt,
    this.endedAt,
    required this.current,
    required this.eventsTotal,
    required this.trainings,
    required this.matches,
    this.attendanceRate,
    required this.pointsAwarded,
  });

  factory SeasonPeriod.fromJson(Map<String, dynamic> json) {
    return SeasonPeriod(
      coachName: json['coach_name'] ?? 'Utilizador removido',
      startedAt: DateTime.parse(json['started_at']),
      endedAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at']) : null,
      current: json['current'] == true,
      eventsTotal: json['events_total'] ?? 0,
      trainings: json['trainings'] ?? 0,
      matches: json['matches'] ?? 0,
      attendanceRate: json['attendance_rate'],
      pointsAwarded: json['points_awarded'] ?? 0,
    );
  }
}

class AuditLogEntry {
  final int id;
  final String action;
  final String? details;
  final DateTime createdAt;
  final String adminName;

  AuditLogEntry({
    required this.id,
    required this.action,
    this.details,
    required this.createdAt,
    required this.adminName,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'],
      action: json['action'],
      details: json['details'],
      createdAt: DateTime.parse(json['created_at']),
      adminName: json['admin']?['name'] ?? 'Utilizador removido',
    );
  }

  /// Rótulo em português, pronto a mostrar, para cada tipo de ação.
  String get actionLabel {
    switch (action) {
      case 'update_team_profile':
        return 'Editou a ficha da equipa';
      case 'update_coach_profile':
        return 'Editou a ficha do treinador';
      case 'transfer_coach':
        return 'Trocou o treinador';
      case 'remove_athlete':
        return 'Removeu um atleta';
      default:
        return action;
    }
  }
}
