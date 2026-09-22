import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

// Regista entradas e saídas de membros da equipa — mesmo espírito do
// CoachHistory. left_at === null significa que o membro ainda está na
// equipa neste momento.
interface MembershipHistoryAttributes {
  id: number;
  team_id: number;
  user_id: number;
  joined_at: Date;
  left_at: Date | null;
  notes: string | null;
  created_at?: Date;
}

type MembershipHistoryCreationAttributes = Optional<MembershipHistoryAttributes, 'id' | 'created_at' | 'left_at' | 'notes'>;

export class MembershipHistory
  extends Model<MembershipHistoryAttributes, MembershipHistoryCreationAttributes>
  implements MembershipHistoryAttributes
{
  public id!: number;
  public team_id!: number;
  public user_id!: number;
  public joined_at!: Date;
  public left_at!: Date | null;
  public notes!: string | null;
  public readonly created_at!: Date;
}

MembershipHistory.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    team_id: { type: DataTypes.INTEGER, allowNull: false },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    joined_at: { type: DataTypes.DATE, allowNull: false },
    left_at: { type: DataTypes.DATE, allowNull: true },
    notes: { type: DataTypes.TEXT, allowNull: true },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'membership_history', timestamps: false }
);
