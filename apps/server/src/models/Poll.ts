import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface PollAttributes {
  id: number;
  team_id: number;
  question: string;
  created_by: number;
  created_at?: Date;
}

type PollCreationAttributes = Optional<PollAttributes, 'id' | 'created_at'>;

export class Poll extends Model<PollAttributes, PollCreationAttributes> implements PollAttributes {
  public id!: number;
  public team_id!: number;
  public question!: string;
  public created_by!: number;
  public readonly created_at!: Date;
}

Poll.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    team_id: { type: DataTypes.INTEGER, allowNull: false },
    question: { type: DataTypes.STRING(300), allowNull: false },
    created_by: { type: DataTypes.INTEGER, allowNull: false },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'polls', timestamps: false }
);
