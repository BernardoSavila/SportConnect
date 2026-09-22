import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface DeviceTokenAttributes {
  id: number;
  user_id: number;
  token: string;
  platform: 'android' | 'ios';
  created_at?: Date;
}

type DeviceTokenCreationAttributes = Optional<DeviceTokenAttributes, 'id' | 'created_at'>;

export class DeviceToken extends Model<DeviceTokenAttributes, DeviceTokenCreationAttributes> implements DeviceTokenAttributes {
  public id!: number;
  public user_id!: number;
  public token!: string;
  public platform!: 'android' | 'ios';
  public readonly created_at!: Date;
}

DeviceToken.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    token: { type: DataTypes.STRING(500), allowNull: false },
    platform: { type: DataTypes.ENUM('android', 'ios'), allowNull: false },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'device_tokens', timestamps: false }
);
