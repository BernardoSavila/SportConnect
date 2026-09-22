import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import { createAchievement } from '../controllers/achievementController';

const router = Router();
router.post('/', authenticate, requireRole('coach', 'admin'), createAchievement);

export default router;
