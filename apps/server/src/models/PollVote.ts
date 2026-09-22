import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface PollVoteAttributes {
  id: number;
  poll_id: number;
  option_id: number;
  user_id: number;
  created_at?: Date;
}

type PollVoteCreationAttributes = Optional<PollVoteAttributes, 'id' | 'created_at'>;

export class PollVote extends Model<PollVoteAttributes, PollVoteCreationAttributes> implements PollVoteAttributes {
  public id!: number;
  public poll_id!: number;
  public option_id!: number;
  public user_id!: number;
  public readonly created_at!: Date;
}

PollVote.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    poll_id: { type: DataTypes.INTEGER, allowNull: false },
    option_id: { type: DataTypes.INTEGER, allowNull: false },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  {
    sequelize,
    tableName: 'poll_votes',
    timestamps: false,
    indexes: [{ unique: true, fields: ['poll_id', 'user_id'] }], // um voto por utilizador por sondagem
  }
);
