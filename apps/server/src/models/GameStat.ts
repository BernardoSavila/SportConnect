import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface GameStatAttributes {
  id: number;
  event_id: number;
  user_id: number;
  goals: number;
  assists: number;
  minutes_played: number;
}

type GameStatCreationAttributes = Optional<GameStatAttributes, 'id' | 'goals' | 'assists' | 'minutes_played'>;

export class GameStat extends Model<GameStatAttributes, GameStatCreationAttributes> implements GameStatAttributes {
  public id!: number;
  public event_id!: number;
  public user_id!: number;
  public goals!: number;
  public assists!: number;
  public minutes_played!: number;
}

GameStat.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    event_id: { type: DataTypes.INTEGER, allowNull: false },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    goals: { type: DataTypes.INTEGER, defaultValue: 0 },
    assists: { type: DataTypes.INTEGER, defaultValue: 0 },
    minutes_played: { type: DataTypes.INTEGER, defaultValue: 0 },
  },
  {
    sequelize,
    tableName: 'game_stats',
    timestamps: false,
    indexes: [{ unique: true, fields: ['event_id', 'user_id'] }],
  }
);
