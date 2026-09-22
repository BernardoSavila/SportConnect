import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { registerDeviceToken } from '../controllers/deviceController';

const router = Router();
router.post('/register-token', authenticate, registerDeviceToken);

export default router;
