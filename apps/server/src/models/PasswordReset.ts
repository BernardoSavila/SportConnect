import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface PasswordResetAttributes {
  id: number;
  user_id: number;
  code_hash: string;
  expires_at: Date;
  used: boolean;
  created_at?: Date;
}

type PasswordResetCreationAttributes = Optional<PasswordResetAttributes, 'id' | 'created_at' | 'used'>;

export class PasswordReset
  extends Model<PasswordResetAttributes, PasswordResetCreationAttributes>
  implements PasswordResetAttributes
{
  public id!: number;
  public user_id!: number;
  public code_hash!: string;
  public expires_at!: Date;
  public used!: boolean;
  public readonly created_at!: Date;
}

PasswordReset.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    // Nunca guardamos o código em texto simples — só o hash (SHA-256),
    // tal como as passwords nunca são guardadas em texto simples.
    code_hash: { type: DataTypes.STRING(64), allowNull: false },
    expires_at: { type: DataTypes.DATE, allowNull: false },
    used: { type: DataTypes.BOOLEAN, defaultValue: false },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'password_resets', timestamps: false }
);
