import { Request, Response, NextFunction } from 'express';
import { Op } from 'sequelize';
import { DirectMessage, User } from '../models';

// Histórico de mensagens privadas com um utilizador específico. Mensagens
// novas chegam em tempo real via Socket.io (ver realtime.ts, eventos
// `dm:join`/`dm:send`); este endpoint só carrega o histórico ao abrir o chat.
export async function getDirectHistory(req: Request, res: Response, next: NextFunction) {
  try {
    const otherUserId = Number(req.params.userId);
    const myId = req.user!.id;
    const messages = await DirectMessage.findAll({
      where: {
        [Op.or]: [
          { sender_id: myId, recipient_id: otherUserId },
          { sender_id: otherUserId, recipient_id: myId },
        ],
      },
      order: [['sent_at', 'ASC']],
      limit: 200,
    });
    res.status(200).json(messages);
  } catch (err) {
    next(err);
  }
}

// Lista de conversas do utilizador — uma entrada por pessoa com quem já
// trocou mensagens, com a última mensagem e quando foi enviada.
export async function listConversations(req: Request, res: Response, next: NextFunction) {
  try {
    const myId = req.user!.id;
    const messages = await DirectMessage.findAll({
      where: { [Op.or]: [{ sender_id: myId }, { recipient_id: myId }] },
      order: [['sent_at', 'DESC']],
    });

    const seen = new Map<number, DirectMessage>();
    for (const m of messages) {
      const otherId = m.sender_id === myId ? m.recipient_id : m.sender_id;
      if (!seen.has(otherId)) seen.set(otherId, m);
    }

    const otherIds = [...seen.keys()];
    const users = otherIds.length
      ? await User.findAll({ where: { id: otherIds }, attributes: ['id', 'name', 'avatar_url'] })
      : [];
    const userById = new Map(users.map((u) => [u.id, u]));

    const conversations = otherIds
      .map((id) => {
        const user = userById.get(id);
        const lastMessage = seen.get(id)!;
        if (!user) return null;
        return {
          user_id: user.id,
          user_name: user.name,
          avatar_url: user.avatar_url,
          last_message: lastMessage.content,
          last_message_type: lastMessage.type,
          sent_at: lastMessage.sent_at,
        };
      })
      .filter(Boolean);

    res.status(200).json(conversations);
  } catch (err) {
    next(err);
  }
}
