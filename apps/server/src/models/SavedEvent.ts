import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface SavedEventAttributes {
  id: number;
  user_id: number;
  event_id: number;
  created_at?: Date;
}

type SavedEventCreationAttributes = Optional<SavedEventAttributes, 'id' | 'created_at'>;

export class SavedEvent extends Model<SavedEventAttributes, SavedEventCreationAttributes> implements SavedEventAttributes {
  public id!: number;
  public user_id!: number;
  public event_id!: number;
  public readonly created_at!: Date;
}

SavedEvent.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    event_id: { type: DataTypes.INTEGER, allowNull: false },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  {
    sequelize,
    tableName: 'saved_events',
    timestamps: false,
    indexes: [{ unique: true, fields: ['user_id', 'event_id'] }],
  }
);
