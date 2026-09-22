import { Request, Response, NextFunction } from 'express';
import { Achievement, User } from '../models';
import { ApiError } from '../middleware/error';

// Atribuição de pontos/medalhas — sem lógica complexa, apenas um registo
// manual feito pelo treinador (conforme "modelo, sem lógica complexa"
// no documento de objetivos do Projeto 1).
export async function createAchievement(req: Request, res: Response, next: NextFunction) {
  try {
    const { user_id, type, points } = req.body;
    if (!user_id || !type) throw new ApiError(400, 'user_id e type são obrigatórios');
    if (points !== undefined && (typeof points !== 'number' || points < 0)) {
      throw new ApiError(400, 'points deve ser um número não negativo');
    }

    const targetUser = await User.findByPk(user_id);
    if (!targetUser) throw new ApiError(404, 'Utilizador não encontrado');

    // Um treinador só pode atribuir pontos a atletas da sua própria equipa.
    if (req.user!.role !== 'admin' && targetUser.team_id !== req.user!.team_id) {
      throw new ApiError(403, 'Só podes atribuir pontos a atletas da tua equipa');
    }

    const achievement = await Achievement.create({
      user_id,
      type,
      points: points ?? 0,
    });
    res.status(201).json(achievement);
  } catch (err) {
    next(err);
  }
}
