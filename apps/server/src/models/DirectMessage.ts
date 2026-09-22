import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

export type DirectMessageType = 'text' | 'image' | 'audio';

interface DirectMessageAttributes {
  id: number;
  sender_id: number;
  recipient_id: number;
  content: string | null;
  media_url: string | null;
  type: DirectMessageType;
  sent_at?: Date;
}

type DirectMessageCreationAttributes = Optional<DirectMessageAttributes, 'id' | 'sent_at' | 'media_url' | 'type' | 'content'>;

export class DirectMessage
  extends Model<DirectMessageAttributes, DirectMessageCreationAttributes>
  implements DirectMessageAttributes
{
  public id!: number;
  public sender_id!: number;
  public recipient_id!: number;
  public content!: string | null;
  public media_url!: string | null;
  public type!: DirectMessageType;
  public readonly sent_at!: Date;
}

DirectMessage.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    sender_id: { type: DataTypes.INTEGER, allowNull: false },
    recipient_id: { type: DataTypes.INTEGER, allowNull: false },
    content: { type: DataTypes.TEXT, allowNull: true },
    media_url: { type: DataTypes.STRING(500), allowNull: true },
    type: { type: DataTypes.ENUM('text', 'image', 'audio'), defaultValue: 'text' },
    sent_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'direct_messages', timestamps: false }
);
