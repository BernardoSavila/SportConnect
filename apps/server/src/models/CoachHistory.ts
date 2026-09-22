import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

// Regista quem treinou cada equipa, e quando — não só o treinador atual.
// Um registo com ended_at === null é o treinador em funções nesse momento;
// quando o Admin troca de treinador, esse registo fecha (ended_at
// passa a ter valor) e um novo é criado, em vez de o antigo ser apagado.
interface CoachHistoryAttributes {
  id: number;
  team_id: number;
  user_id: number;
  started_at: Date;
  ended_at: Date | null;
  notes: string | null;
  created_at?: Date;
}

type CoachHistoryCreationAttributes = Optional<CoachHistoryAttributes, 'id' | 'created_at' | 'ended_at' | 'notes'>;

export class CoachHistory
  extends Model<CoachHistoryAttributes, CoachHistoryCreationAttributes>
  implements CoachHistoryAttributes
{
  public id!: number;
  public team_id!: number;
  public user_id!: number;
  public started_at!: Date;
  public ended_at!: Date | null;
  public notes!: string | null;
  public readonly created_at!: Date;
}

CoachHistory.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    team_id: { type: DataTypes.INTEGER, allowNull: false },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    started_at: { type: DataTypes.DATE, allowNull: false },
    ended_at: { type: DataTypes.DATE, allowNull: true },
    notes: { type: DataTypes.TEXT, allowNull: true },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'coach_history', timestamps: false }
);
