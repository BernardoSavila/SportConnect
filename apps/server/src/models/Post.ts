import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface PostAttributes {
  id: number;
  team_id: number;
  author_id: number;
  content: string;
  media_url: string | null;
  // Aviso oficial do Admin — destacado visualmente no feed,
  // distinto dos avisos normais do treinador.
  is_official: boolean;
  created_at?: Date;
}

type PostCreationAttributes = Optional<PostAttributes, 'id' | 'created_at' | 'media_url' | 'is_official'>;

export class Post extends Model<PostAttributes, PostCreationAttributes> implements PostAttributes {
  public id!: number;
  public team_id!: number;
  public author_id!: number;
  public content!: string;
  public media_url!: string | null;
  public is_official!: boolean;
  public readonly created_at!: Date;
}

Post.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    team_id: { type: DataTypes.INTEGER, allowNull: false },
    author_id: { type: DataTypes.INTEGER, allowNull: false },
    content: { type: DataTypes.TEXT, allowNull: false },
    media_url: { type: DataTypes.STRING(500), allowNull: true },
    is_official: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  { sequelize, tableName: 'posts', timestamps: false }
);
