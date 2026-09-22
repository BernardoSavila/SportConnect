import { Request, Response, NextFunction } from 'express';
import { Post, PostLike } from '../models';
import { ApiError } from '../middleware/error';

async function withLikeInfo(posts: Post[], userId: number) {
  const postIds = posts.map((p) => p.id);
  if (postIds.length === 0) return [];

  const likes = await PostLike.findAll({ where: { post_id: postIds } });
  const countByPost = new Map<number, number>();
  const likedByMe = new Set<number>();
  for (const like of likes) {
    countByPost.set(like.post_id, (countByPost.get(like.post_id) || 0) + 1);
    if (like.user_id === userId) likedByMe.add(like.post_id);
  }

  return posts.map((p) => ({
    ...p.toJSON(),
    likes_count: countByPost.get(p.id) || 0,
    liked_by_me: likedByMe.has(p.id),
  }));
}

export async function listFeed(req: Request, res: Response, next: NextFunction) {
  try {
    const teamId = Number(req.query.teamId);
    if (!teamId) throw new ApiError(400, 'teamId é obrigatório');
    const posts = await Post.findAll({ where: { team_id: teamId }, order: [['created_at', 'DESC']] });
    const result = await withLikeInfo(posts, req.user!.id);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function createPost(req: Request, res: Response, next: NextFunction) {
  try {
    const { team_id, content, media_url } = req.body;
    if (!team_id || !content) throw new ApiError(400, 'team_id e content são obrigatórios');
    const post = await Post.create({
      team_id,
      author_id: req.user!.id,
      content,
      media_url: media_url ?? null,
      // Publicações feitas pelo Admin ficam sempre marcadas como
      // "aviso oficial" — destacadas no feed, sem ser preciso pedir isto
      // explicitamente a cada publicação.
      is_official: req.user!.role === 'admin',
    });
    res.status(201).json({ ...post.toJSON(), likes_count: 0, liked_by_me: false });
  } catch (err) {
    next(err);
  }
}

// Edita o texto e/ou a imagem de uma publicação já existente — o
// treinador ou o admin da equipa a que a publicação pertence.
export async function updatePost(req: Request, res: Response, next: NextFunction) {
  try {
    const post = await Post.findByPk(req.params.id);
    if (!post) throw new ApiError(404, 'Publicação não encontrada');
    if (post.team_id !== req.user!.team_id) {
      throw new ApiError(403, 'Só podes editar publicações da tua equipa');
    }

    const { content, media_url } = req.body;
    if (content !== undefined) {
      if (!content) throw new ApiError(400, 'content não pode ficar vazio');
      post.content = content;
    }
    if (media_url !== undefined) post.media_url = media_url;

    await post.save();
    const [result] = await withLikeInfo([post], req.user!.id);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

// Elimina uma publicação e os "gostos" associados.
export async function deletePost(req: Request, res: Response, next: NextFunction) {
  try {
    const post = await Post.findByPk(req.params.id);
    if (!post) throw new ApiError(404, 'Publicação não encontrada');
    if (post.team_id !== req.user!.team_id) {
      throw new ApiError(403, 'Só podes eliminar publicações da tua equipa');
    }

    await PostLike.destroy({ where: { post_id: post.id } });
    await post.destroy();

    res.status(200).json({ message: 'Publicação eliminada com sucesso' });
  } catch (err) {
    next(err);
  }
}

// Alterna o "gosto" do utilizador autenticado num post (like/unlike).
export async function toggleLike(req: Request, res: Response, next: NextFunction) {
  try {
    const postId = Number(req.params.id);
    const post = await Post.findByPk(postId);
    if (!post) throw new ApiError(404, 'Post não encontrado');

    const existing = await PostLike.findOne({ where: { post_id: postId, user_id: req.user!.id } });
    let liked: boolean;
    if (existing) {
      await existing.destroy();
      liked = false;
    } else {
      await PostLike.create({ post_id: postId, user_id: req.user!.id });
      liked = true;
    }
    const likesCount = await PostLike.count({ where: { post_id: postId } });
    res.status(200).json({ post_id: postId, liked_by_me: liked, likes_count: likesCount });
  } catch (err) {
    next(err);
  }
}
