import { Request, Response, NextFunction } from 'express';
import { DeviceToken } from '../models';
import { ApiError } from '../middleware/error';

// Stub: apenas guarda o token. O envio real de notificações via
// Firebase Cloud Messaging fica documentado para o Projeto 2.
export async function registerDeviceToken(req: Request, res: Response, next: NextFunction) {
  try {
    const { token, platform } = req.body;
    if (!token || !platform) throw new ApiError(400, 'token e platform são obrigatórios');
    if (!['android', 'ios'].includes(platform)) throw new ApiError(400, 'platform deve ser android ou ios');
    const record = await DeviceToken.create({ user_id: req.user!.id, token, platform });
    res.status(201).json(record);
  } catch (err) {
    next(err);
  }
}
