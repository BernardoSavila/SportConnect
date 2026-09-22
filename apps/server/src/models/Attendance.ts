import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

export type AttendanceStatus = 'pending' | 'present' | 'absent' | 'waitlist';

interface AttendanceAttributes {
  id: number;
  event_id: number;
  user_id: number;
  status: AttendanceStatus;
  confirmed_at: Date | null;
}

type AttendanceCreationAttributes = Optional<AttendanceAttributes, 'id' | 'status' | 'confirmed_at'>;

export class Attendance extends Model<AttendanceAttributes, AttendanceCreationAttributes> implements AttendanceAttributes {
  public id!: number;
  public event_id!: number;
  public user_id!: number;
  public status!: AttendanceStatus;
  public confirmed_at!: Date | null;
}

Attendance.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    event_id: { type: DataTypes.INTEGER, allowNull: false },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    status: { type: DataTypes.ENUM('pending', 'present', 'absent', 'waitlist'), defaultValue: 'pending' },
    confirmed_at: { type: DataTypes.DATE, allowNull: true },
  },
  {
    sequelize,
    tableName: 'attendance',
    timestamps: false,
    indexes: [{ unique: true, fields: ['event_id', 'user_id'] }],
  }
);
