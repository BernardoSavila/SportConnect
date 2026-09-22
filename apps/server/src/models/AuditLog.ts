import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

// Regista ações administrativas do Admin, para responsabilização
// institucional — quem fez o quê, e quando. Nunca editado nem apagado
// depois de criado.
interface AuditLogAttributes {
  id: number;
  team_id: number;
  admin_id: number;
  action: string;
  details: string | null;
  created_at?: Date;
}

type AuditLogCreationAttributes = Optional<AuditLogAttributes, 'id' | 'created_at' | 'details'>;

export class AuditLog extends Model<AuditLogAttributes, AuditLogCreationAttributes> implements AuditLogAttributes {
  public id!: number;
  public team_id!: number;
  public admin_id!: number;
  public action!: string;
  public details!: string | null;
  public readonly created_at!: Date;
}

AuditLog.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    team_id: { type: DataTypes.INTEGER, allowNull: false },
    admin_id: { type: DataTypes.INTEGER, allowNull: false },
    action: { type: DataTypes.STRING(80), allowNull: false },
    details: { type: DataTypes.TEXT, allowNull: true },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'audit_log', timestamps: false }
);
