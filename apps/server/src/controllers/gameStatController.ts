import { Request, Response, NextFunction } from 'express';
import { GameStat, User } from '../models';
import { ApiError } from '../middleware/error';

// Registar/atualizar estatísticas de um atleta num evento (treinador).
export async function upsertGameStat(req: Request, res: Response, next: NextFunction) {
  try {
    const eventId = Number(req.params.id);
    const { user_id, goals, assists, minutes_played } = req.body;
    if (!user_id) throw new ApiError(400, 'user_id é obrigatório');

    let stat = await GameStat.findOne({ where: { event_id: eventId, user_id } });
    if (stat) {
      stat.goals = goals ?? stat.goals;
      stat.assists = assists ?? stat.assists;
      stat.minutes_played = minutes_played ?? stat.minutes_played;
      await stat.save();
    } else {
      stat = await GameStat.create({
        event_id: eventId,
        user_id,
        goals: goals ?? 0,
        assists: assists ?? 0,
        minutes_played: minutes_played ?? 0,
      });
    }
    res.status(200).json(stat);
  } catch (err) {
    next(err);
  }
}

export async function listGameStats(req: Request, res: Response, next: NextFunction) {
  try {
    const eventId = Number(req.params.id);
    const stats = await GameStat.findAll({ where: { event_id: eventId } });
    const userIds = stats.map((s) => s.user_id);
    const users = userIds.length ? await User.findAll({ where: { id: userIds }, attributes: ['id', 'name'] }) : [];
    const nameById = new Map(users.map((u) => [u.id, u.name]));
    res.status(200).json(stats.map((s) => ({ ...s.toJSON(), user_name: nameById.get(s.user_id) || 'Desconhecido' })));
  } catch (err) {
    next(err);
  }
}

// Totais de carreira de um atleta — usado no ecrã de detalhe do atleta.
export async function getCareerStats(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = Number(req.params.id);
    const stats = await GameStat.findAll({ where: { user_id: userId } });
    const totals = stats.reduce(
      (acc, s) => ({
        goals: acc.goals + s.goals,
        assists: acc.assists + s.assists,
        minutes_played: acc.minutes_played + s.minutes_played,
        games: acc.games + 1,
      }),
      { goals: 0, assists: 0, minutes_played: 0, games: 0 }
    );
    res.status(200).json(totals);
  } catch (err) {
    next(err);
  }
}
