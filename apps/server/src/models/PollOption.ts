import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface PollOptionAttributes {
  id: number;
  poll_id: number;
  text: string;
}

type PollOptionCreationAttributes = Optional<PollOptionAttributes, 'id'>;

export class PollOption extends Model<PollOptionAttributes, PollOptionCreationAttributes> implements PollOptionAttributes {
  public id!: number;
  public poll_id!: number;
  public text!: string;
}

PollOption.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    poll_id: { type: DataTypes.INTEGER, allowNull: false },
    text: { type: DataTypes.STRING(200), allowNull: false },
  },
  { sequelize, tableName: 'poll_options', timestamps: false }
);
