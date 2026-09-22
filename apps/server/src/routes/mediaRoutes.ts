import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { uploadMiddleware, handleUpload } from '../controllers/uploadController';

const router = Router();

router.post('/upload', authenticate, uploadMiddleware, handleUpload);

export default router;
