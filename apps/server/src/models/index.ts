import { sequelize } from '../config/database';
import { User } from './User';
import { Team } from './Team';
import { Event } from './Event';
import { Attendance } from './Attendance';
import { Post } from './Post';
import { PostLike } from './PostLike';
import { Achievement } from './Achievement';
import { DeviceToken } from './DeviceToken';
import { ChatMessage } from './ChatMessage';
import { Poll } from './Poll';
import { PollOption } from './PollOption';
import { PollVote } from './PollVote';
import { GameStat } from './GameStat';
import { DirectMessage } from './DirectMessage';
import { SavedEvent } from './SavedEvent';
import { PasswordReset } from './PasswordReset';
import { CoachHistory } from './CoachHistory';
import { MembershipHistory } from './MembershipHistory';
import { AuditLog } from './AuditLog';

// Associations
Team.hasMany(User, { foreignKey: 'team_id' });
User.belongsTo(Team, { foreignKey: 'team_id' });

Team.hasMany(Event, { foreignKey: 'team_id' });
Event.belongsTo(Team, { foreignKey: 'team_id' });
User.hasMany(Event, { foreignKey: 'created_by' });
Event.belongsTo(User, { foreignKey: 'created_by', as: 'creator' });

Event.hasMany(Attendance, { foreignKey: 'event_id' });
Attendance.belongsTo(Event, { foreignKey: 'event_id' });
User.hasMany(Attendance, { foreignKey: 'user_id' });
Attendance.belongsTo(User, { foreignKey: 'user_id' });

Team.hasMany(Post, { foreignKey: 'team_id' });
Post.belongsTo(Team, { foreignKey: 'team_id' });
User.hasMany(Post, { foreignKey: 'author_id' });
Post.belongsTo(User, { foreignKey: 'author_id', as: 'author' });

Post.hasMany(PostLike, { foreignKey: 'post_id' });
PostLike.belongsTo(Post, { foreignKey: 'post_id' });
User.hasMany(PostLike, { foreignKey: 'user_id' });
PostLike.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(Achievement, { foreignKey: 'user_id' });
Achievement.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(DeviceToken, { foreignKey: 'user_id' });
DeviceToken.belongsTo(User, { foreignKey: 'user_id' });

Team.hasMany(ChatMessage, { foreignKey: 'team_id' });
ChatMessage.belongsTo(Team, { foreignKey: 'team_id' });
User.hasMany(ChatMessage, { foreignKey: 'sender_id' });
ChatMessage.belongsTo(User, { foreignKey: 'sender_id' });

Team.hasMany(Poll, { foreignKey: 'team_id' });
Poll.belongsTo(Team, { foreignKey: 'team_id' });
User.hasMany(Poll, { foreignKey: 'created_by' });
Poll.belongsTo(User, { foreignKey: 'created_by' });

Poll.hasMany(PollOption, { foreignKey: 'poll_id' });
PollOption.belongsTo(Poll, { foreignKey: 'poll_id' });

Poll.hasMany(PollVote, { foreignKey: 'poll_id' });
PollVote.belongsTo(Poll, { foreignKey: 'poll_id' });
PollOption.hasMany(PollVote, { foreignKey: 'option_id' });
PollVote.belongsTo(PollOption, { foreignKey: 'option_id' });
User.hasMany(PollVote, { foreignKey: 'user_id' });
PollVote.belongsTo(User, { foreignKey: 'user_id' });

Event.hasMany(GameStat, { foreignKey: 'event_id' });
GameStat.belongsTo(Event, { foreignKey: 'event_id' });
User.hasMany(GameStat, { foreignKey: 'user_id' });
GameStat.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(DirectMessage, { foreignKey: 'sender_id', as: 'sentMessages' });
User.hasMany(DirectMessage, { foreignKey: 'recipient_id', as: 'receivedMessages' });
DirectMessage.belongsTo(User, { foreignKey: 'sender_id', as: 'sender' });
DirectMessage.belongsTo(User, { foreignKey: 'recipient_id', as: 'recipient' });

Event.hasMany(SavedEvent, { foreignKey: 'event_id' });
SavedEvent.belongsTo(Event, { foreignKey: 'event_id' });
User.hasMany(SavedEvent, { foreignKey: 'user_id' });
SavedEvent.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(PasswordReset, { foreignKey: 'user_id' });
PasswordReset.belongsTo(User, { foreignKey: 'user_id' });

Team.hasMany(CoachHistory, { foreignKey: 'team_id' });
CoachHistory.belongsTo(Team, { foreignKey: 'team_id' });
User.hasMany(CoachHistory, { foreignKey: 'user_id' });
CoachHistory.belongsTo(User, { foreignKey: 'user_id' });

Team.hasMany(MembershipHistory, { foreignKey: 'team_id' });
MembershipHistory.belongsTo(Team, { foreignKey: 'team_id' });
User.hasMany(MembershipHistory, { foreignKey: 'user_id' });
MembershipHistory.belongsTo(User, { foreignKey: 'user_id' });

Team.hasMany(AuditLog, { foreignKey: 'team_id' });
AuditLog.belongsTo(Team, { foreignKey: 'team_id' });
User.hasMany(AuditLog, { foreignKey: 'admin_id' });
AuditLog.belongsTo(User, { foreignKey: 'admin_id' });

export {
  sequelize,
  User,
  Team,
  Event,
  Attendance,
  Post,
  PostLike,
  Achievement,
  DeviceToken,
  ChatMessage,
  Poll,
  PollOption,
  PollVote,
  GameStat,
  DirectMessage,
  SavedEvent,
  PasswordReset,
  CoachHistory,
  MembershipHistory,
  AuditLog,
};
