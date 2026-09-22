import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { getDirectHistory, listConversations } from '../controllers/directMessageController';

const router = Router();
router.get('/conversations', authenticate, listConversations);
router.get('/:userId', authenticate, getDirectHistory);

export default router;
