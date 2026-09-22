import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

export type EventType = 'training' | 'match';

interface EventAttributes {
  id: number;
  team_id: number;
  title: string;
  description: string | null;
  start_time: Date;
  end_time: Date;
  location: string | null;
  type: EventType;
  created_by: number;
  max_capacity: number | null;
  created_at?: Date;
}

type EventCreationAttributes = Optional<EventAttributes, 'id' | 'created_at' | 'description' | 'location' | 'max_capacity'>;

export class Event extends Model<EventAttributes, EventCreationAttributes> implements EventAttributes {
  public id!: number;
  public team_id!: number;
  public title!: string;
  public description!: string | null;
  public start_time!: Date;
  public end_time!: Date;
  public location!: string | null;
  public type!: EventType;
  public created_by!: number;
  public max_capacity!: number | null;
  public readonly created_at!: Date;
}

Event.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    team_id: { type: DataTypes.INTEGER, allowNull: false },
    title: { type: DataTypes.STRING(200), allowNull: false },
    description: { type: DataTypes.TEXT, allowNull: true },
    start_time: { type: DataTypes.DATE, allowNull: false },
    end_time: { type: DataTypes.DATE, allowNull: false },
    location: { type: DataTypes.STRING(200), allowNull: true },
    type: { type: DataTypes.ENUM('training', 'match'), allowNull: false },
    created_by: { type: DataTypes.INTEGER, allowNull: false },
    // Se definido, limita quantos "present" cabem no evento — os restantes
    // ficam automaticamente em lista de espera (ver Attendance.status).
    max_capacity: { type: DataTypes.INTEGER, allowNull: true },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'events', timestamps: false }
);
