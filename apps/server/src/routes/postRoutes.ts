import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import { listFeed, createPost, updatePost, deletePost, toggleLike } from '../controllers/postController';

const feedRouter = Router();
feedRouter.get('/', authenticate, listFeed);

const postsRouter = Router();
postsRouter.post('/', authenticate, requireRole('coach', 'admin'), createPost);
postsRouter.patch('/:id', authenticate, requireRole('coach', 'admin'), updatePost);
postsRouter.delete('/:id', authenticate, requireRole('coach', 'admin'), deletePost);
postsRouter.post('/:id/like', authenticate, toggleLike);

export { feedRouter, postsRouter };
