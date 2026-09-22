import { Router } from 'express';
import { Request, Response, NextFunction } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import { checkAndSendReminders } from '../reminders';

const router = Router();

// Permite ao treinador disparar a verificação manualmente (por exemplo,
// para testar ou para um lembrete imediato), além da execução automática
// de hora a hora.
router.post('/check', authenticate, requireRole('coach', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const count = await checkAndSendReminders();
    res.status(200).json({ reminders_sent: count });
  } catch (err) {
    next(err);
  }
});

export default router;
