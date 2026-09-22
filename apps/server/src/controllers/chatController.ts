import { Request, Response, NextFunction } from 'express';
import { ChatMessage } from '../models';
import { ApiError } from '../middleware/error';

// Histórico de mensagens de uma equipa. As mensagens novas chegam em
// tempo real via Socket.io (ver src/realtime.ts); este endpoint serve
// para carregar o histórico quando o utilizador abre o chat.
export async function listConversations(req: Request, res: Response, next: NextFunction) {
  try {
    const teamId = Number(req.query.teamId);
    if (!teamId) throw new ApiError(400, 'teamId é obrigatório');
    const messages = await ChatMessage.findAll({
      where: { team_id: teamId },
      order: [['sent_at', 'ASC']],
      limit: 100,
    });
    res.status(200).json(messages);
  } catch (err) {
    next(err);
  }
}
