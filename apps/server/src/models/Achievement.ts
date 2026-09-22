import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface AchievementAttributes {
  id: number;
  user_id: number;
  type: string;
  points: number;
  awarded_at?: Date;
}

type AchievementCreationAttributes = Optional<AchievementAttributes, 'id' | 'awarded_at' | 'points'>;

export class Achievement extends Model<AchievementAttributes, AchievementCreationAttributes> implements AchievementAttributes {
  public id!: number;
  public user_id!: number;
  public type!: string;
  public points!: number;
  public readonly awarded_at!: Date;
}

Achievement.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    type: { type: DataTypes.STRING(100), allowNull: false },
    points: { type: DataTypes.INTEGER, defaultValue: 0 },
    awarded_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'achievements', timestamps: false }
);
