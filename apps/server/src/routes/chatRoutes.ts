import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { listConversations } from '../controllers/chatController';

const router = Router();
router.get('/conversations', authenticate, listConversations);

export default router;
