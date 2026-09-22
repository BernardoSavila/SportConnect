import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

export type ChatMessageType = 'text' | 'image' | 'audio';

interface ChatMessageAttributes {
  id: number;
  team_id: number;
  sender_id: number;
  content: string | null;
  media_url: string | null;
  type: ChatMessageType;
  sent_at?: Date;
}

type ChatMessageCreationAttributes = Optional<ChatMessageAttributes, 'id' | 'sent_at' | 'media_url' | 'type' | 'content'>;

export class ChatMessage extends Model<ChatMessageAttributes, ChatMessageCreationAttributes> implements ChatMessageAttributes {
  public id!: number;
  public team_id!: number;
  public sender_id!: number;
  public content!: string | null;
  public media_url!: string | null;
  public type!: ChatMessageType;
  public readonly sent_at!: Date;
}

ChatMessage.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    team_id: { type: DataTypes.INTEGER, allowNull: false },
    sender_id: { type: DataTypes.INTEGER, allowNull: false },
    content: { type: DataTypes.TEXT, allowNull: true },
    media_url: { type: DataTypes.STRING(500), allowNull: true },
    type: { type: DataTypes.ENUM('text', 'image', 'audio'), defaultValue: 'text' },
    sent_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'chat_messages', timestamps: false }
);
