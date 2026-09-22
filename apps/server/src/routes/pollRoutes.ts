import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import { createPoll, listPolls, updatePoll, deletePoll, votePoll } from '../controllers/pollController';

const router = Router();
router.get('/', authenticate, listPolls);
router.post('/', authenticate, requireRole('coach', 'admin'), createPoll);
router.patch('/:id', authenticate, requireRole('coach', 'admin'), updatePoll);
router.delete('/:id', authenticate, requireRole('coach', 'admin'), deletePoll);
router.post('/:id/vote', authenticate, votePoll);

export default router;
