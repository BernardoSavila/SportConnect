import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { generateMonthlyReport } from '../controllers/reportController';

const router = Router();
router.get('/monthly', authenticate, generateMonthlyReport);

export default router;
