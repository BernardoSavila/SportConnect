import { DataTypes, Model, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface PostLikeAttributes {
  id: number;
  post_id: number;
  user_id: number;
  created_at?: Date;
}

type PostLikeCreationAttributes = Optional<PostLikeAttributes, 'id' | 'created_at'>;

export class PostLike extends Model<PostLikeAttributes, PostLikeCreationAttributes> implements PostLikeAttributes {
  public id!: number;
  public post_id!: number;
  public user_id!: number;
  public readonly created_at!: Date;
}

PostLike.init(
  {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    post_id: { type: DataTypes.INTEGER, allowNull: false },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  },
  {
    sequelize,
    tableName: 'post_likes',
    timestamps: false,
    indexes: [{ unique: true, fields: ['post_id', 'user_id'] }],
  }
);
