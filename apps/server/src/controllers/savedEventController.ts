import { Request, Response, NextFunction } from 'express';
import { SavedEvent, Event } from '../models';

// Marca/desmarca um evento como "adicionado ao meu calendário" — usado
// pelo calendário mensal dentro da app (em vez de abrir o Google Calendar).
export async function toggleSaveEvent(req: Request, res: Response, next: NextFunction) {
  try {
    const eventId = Number(req.params.id);
    const userId = req.user!.id;

    const existing = await SavedEvent.findOne({ where: { user_id: userId, event_id: eventId } });
    if (existing) {
      await existing.destroy();
      return res.status(200).json({ saved: false });
    }

    await SavedEvent.create({ user_id: userId, event_id: eventId });
    res.status(200).json({ saved: true });
  } catch (err) {
    next(err);
  }
}

// Lista os eventos (completos) que o utilizador autenticado guardou no seu
// calendário pessoal — usado para desenhar os círculos no calendário mensal.
export async function listSavedEvents(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user!.id;
    const saved = await SavedEvent.findAll({ where: { user_id: userId } });
    const eventIds = saved.map((s) => s.event_id);
    if (eventIds.length === 0) return res.status(200).json([]);

    const events = await Event.findAll({ where: { id: eventIds } });
    res.status(200).json(events);
  } catch (err) {
    next(err);
  }
}
