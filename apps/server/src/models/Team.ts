import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface TeamAttributes {
  id: number;
  name: string;
  description: string | null;
  invite_code: string;
  founded_at: Date | null;
  age_group: string | null;
  modality: string | null;
  home_venue: string | null;
  // Início da época corrente — usado para filtrar "Atividade da Época"
  // nas estatísticas e no relatório, em vez de contar desde sempre.
  season_started_at: Date | null;
  created_at?: Date;
}

type TeamCreationAttributes = Optional<
  TeamAttributes,
  | 'id'
  | 'created_at'
  | 'description'
  | 'invite_code'
  | 'founded_at'
  | 'age_group'
  | 'modality'
  | 'home_venue'
  | 'season_started_at'
>;

export class Team extends Model<TeamAttributes, TeamCreationAttributes> implements TeamAttributes {
  public id!: number;
  public name!: string;
  public description!: string | null;
  public invite_code!: string;
  public founded_at!: Date | null;
  public age_group!: string | null;
  public modality!: string | null;
  public home_venue!: string | null;
  public season_started_at!: Date | null;
  public readonly created_at!: Date;
}

function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sem O/0/I/1 para evitar confusão
  let code = '';
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
}

Team.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    name: { type: DataTypes.STRING(120), allowNull: false },
    description: { type: DataTypes.TEXT, allowNull: true },
    invite_code: {
      type: DataTypes.STRING(8),
      allowNull: false,
      unique: true,
      defaultValue: generateInviteCode,
    },
    // Dados institucionais — geridos pelo Admin (role 'admin') da
    // equipa, para além do que o Treinador já gere no dia a dia.
    founded_at: { type: DataTypes.DATE, allowNull: true },
    age_group: { type: DataTypes.STRING(40), allowNull: true },
    modality: { type: DataTypes.STRING(60), allowNull: true },
    home_venue: { type: DataTypes.STRING(120), allowNull: true },
    season_started_at: { type: DataTypes.DATE, allowNull: true },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'teams', timestamps: false }
);
