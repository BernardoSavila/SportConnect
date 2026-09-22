import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

export type UserRole = 'athlete' | 'coach' | 'admin';

interface UserAttributes {
  id: number;
  email: string;
  password_hash: string;
  name: string;
  role: UserRole;
  team_id: number | null;
  avatar_url: string | null;
  guardian_name: string | null;
  guardian_phone: string | null;
  emergency_contact_name: string | null;
  emergency_contact_phone: string | null;
  position: string | null;
  jersey_number: number | null;
  // Ficha do treinador — só relevante quando role === 'coach'. Mantida
  // e gerida pelo Admin (role === 'admin') da equipa.
  coach_started_at: Date | null;
  coach_phone: string | null;
  coach_certification: string | null;
  coach_notes: string | null;
  created_at?: Date;
}

type UserCreationAttributes = Optional<
  UserAttributes,
  | 'id'
  | 'created_at'
  | 'team_id'
  | 'avatar_url'
  | 'guardian_name'
  | 'guardian_phone'
  | 'emergency_contact_name'
  | 'emergency_contact_phone'
  | 'position'
  | 'jersey_number'
  | 'coach_started_at'
  | 'coach_phone'
  | 'coach_certification'
  | 'coach_notes'
>;

export class User extends Model<UserAttributes, UserCreationAttributes> implements UserAttributes {
  public id!: number;
  public email!: string;
  public password_hash!: string;
  public name!: string;
  public role!: UserRole;
  public team_id!: number | null;
  public avatar_url!: string | null;
  public guardian_name!: string | null;
  public guardian_phone!: string | null;
  public emergency_contact_name!: string | null;
  public emergency_contact_phone!: string | null;
  public position!: string | null;
  public jersey_number!: number | null;
  public coach_started_at!: Date | null;
  public coach_phone!: string | null;
  public coach_certification!: string | null;
  public coach_notes!: string | null;
  public readonly created_at!: Date;
}

User.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    email: { type: DataTypes.STRING(255), unique: true, allowNull: false },
    password_hash: { type: DataTypes.STRING(255), allowNull: false },
    name: { type: DataTypes.STRING(120), allowNull: false },
    role: { type: DataTypes.ENUM('athlete', 'coach', 'admin'), defaultValue: 'athlete' },
    team_id: { type: DataTypes.INTEGER, allowNull: true },
    avatar_url: { type: DataTypes.STRING(500), allowNull: true },
    // Relevante sobretudo em desporto jovem — encarregado de educação e
    // contacto de emergência, visíveis ao treinador.
    guardian_name: { type: DataTypes.STRING(120), allowNull: true },
    guardian_phone: { type: DataTypes.STRING(30), allowNull: true },
    emergency_contact_name: { type: DataTypes.STRING(120), allowNull: true },
    emergency_contact_phone: { type: DataTypes.STRING(30), allowNull: true },
    // Dados de "ficha de jogador" — opcionais, o atleta preenche se quiser.
    position: { type: DataTypes.STRING(40), allowNull: true },
    jersey_number: { type: DataTypes.INTEGER, allowNull: true },
    // Ficha do treinador, gerida pelo Admin/Admin da equipa.
    coach_started_at: { type: DataTypes.DATE, allowNull: true },
    coach_phone: { type: DataTypes.STRING(30), allowNull: true },
    coach_certification: { type: DataTypes.STRING(120), allowNull: true },
    coach_notes: { type: DataTypes.TEXT, allowNull: true },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'users', timestamps: false }
);
