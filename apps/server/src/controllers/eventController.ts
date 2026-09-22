import { Request, Response, NextFunction } from 'express';
import { Event, Attendance, User, SavedEvent, GameStat } from '../models';
import { ApiError } from '../middleware/error';

export async function listEvents(req: Request, res: Response, next: NextFunction) {
  try {
    const teamId = Number(req.query.teamId);
    if (!teamId) throw new ApiError(400, 'teamId é obrigatório');
    const events = await Event.findAll({ where: { team_id: teamId }, order: [['start_time', 'ASC']] });
    res.status(200).json(events);
  } catch (err) {
    next(err);
  }
}

export async function getEvent(req: Request, res: Response, next: NextFunction) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) throw new ApiError(404, 'Evento não encontrado');

    const attendance = await Attendance.findAll({ where: { event_id: event.id } });
    const attendanceByUser = new Map(attendance.map((a) => [a.user_id, a]));

    // Lista completa dos atletas da equipa, com o estado de presença de
    // cada um (ou "pending" por omissão, se ainda não confirmaram) — dá
    // ao treinador uma vista imediata de quem falta confirmar.
    const athletes = await User.findAll({
      where: { team_id: event.team_id, role: 'athlete' },
      attributes: ['id', 'name'],
      order: [['name', 'ASC']],
    });

    const roster = athletes.map((u) => {
      const record = attendanceByUser.get(u.id);
      return {
        user_id: u.id,
        user_name: u.name,
        status: record?.status || 'pending',
      };
    });

    res.status(200).json({ ...event.toJSON(), attendance: roster });
  } catch (err) {
    next(err);
  }
}

export async function createEvent(req: Request, res: Response, next: NextFunction) {
  try {
    const { team_id, title, description, start_time, end_time, location, type, recurrence, max_capacity } = req.body;
    if (!team_id || !title || !start_time || !end_time || !type) {
      throw new ApiError(400, 'team_id, title, start_time, end_time e type são obrigatórios');
    }
    if (!['training', 'match'].includes(type)) {
      throw new ApiError(400, 'type deve ser "training" ou "match"');
    }

    const start = new Date(start_time);
    const end = new Date(end_time);
    const durationMs = end.getTime() - start.getTime();
    const capacity = max_capacity !== undefined && max_capacity !== null ? Number(max_capacity) : null;

    // Sem recorrência: comportamento normal, um único evento.
    if (!recurrence || !Array.isArray(recurrence.days_of_week) || recurrence.days_of_week.length === 0) {
      const event = await Event.create({
        team_id,
        title,
        description: description ?? null,
        start_time: start,
        end_time: end,
        location: location ?? null,
        type,
        created_by: req.user!.id,
        max_capacity: capacity,
      });
      return res.status(201).json(event);
    }

    // Com recorrência: gera uma ocorrência por cada dia da semana indicado
    // (0=Domingo..6=Sábado), entre a data inicial e `recurrence.until`,
    // com um limite de segurança de 60 ocorrências.
    const until = recurrence.until ? new Date(recurrence.until) : null;
    if (!until) throw new ApiError(400, 'recurrence.until é obrigatório para eventos recorrentes');

    const daysSet = new Set<number>(recurrence.days_of_week);
    const createdEvents = [];
    const cursor = new Date(start);
    let guard = 0;

    while (cursor <= until && guard < 60) {
      guard++;
      if (daysSet.has(cursor.getDay())) {
        const occStart = new Date(cursor);
        const occEnd = new Date(occStart.getTime() + durationMs);
        const event = await Event.create({
          team_id,
          title,
          description: description ?? null,
          start_time: occStart,
          end_time: occEnd,
          location: location ?? null,
          type,
          created_by: req.user!.id,
          max_capacity: capacity,
        });
        createdEvents.push(event);
      }
      cursor.setDate(cursor.getDate() + 1);
    }

    res.status(201).json({ events: createdEvents, count: createdEvents.length });
  } catch (err) {
    next(err);
  }
}

// Duplica um evento existente para uma nova data/hora — poupa o treinador
// de preencher tudo outra vez para eventos parecidos.
export async function duplicateEvent(req: Request, res: Response, next: NextFunction) {
  try {
    const original = await Event.findByPk(req.params.id);
    if (!original) throw new ApiError(404, 'Evento não encontrado');

    const { start_time, end_time } = req.body;
    if (!start_time || !end_time) throw new ApiError(400, 'start_time e end_time são obrigatórios');

    const duplicate = await Event.create({
      team_id: original.team_id,
      title: original.title,
      description: original.description,
      start_time: new Date(start_time),
      end_time: new Date(end_time),
      location: original.location,
      type: original.type,
      created_by: req.user!.id,
      max_capacity: original.max_capacity,
    });
    res.status(201).json(duplicate);
  } catch (err) {
    next(err);
  }
}

// Edita um evento existente — só o treinador da respetiva equipa (ou um
// admin) pode alterá-lo. Todos os campos são opcionais: só o que for
// enviado é atualizado.
export async function updateEvent(req: Request, res: Response, next: NextFunction) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) throw new ApiError(404, 'Evento não encontrado');
    if (req.user!.role !== 'admin' && event.team_id !== req.user!.team_id) {
      throw new ApiError(403, 'Só podes editar eventos da tua equipa');
    }

    const { title, description, start_time, end_time, location, type, max_capacity } = req.body;
    if (type !== undefined && !['training', 'match'].includes(type)) {
      throw new ApiError(400, 'type deve ser "training" ou "match"');
    }

    if (title !== undefined) {
      if (!title) throw new ApiError(400, 'title não pode ficar vazio');
      event.title = title;
    }
    if (description !== undefined) event.description = description;
    if (start_time !== undefined) event.start_time = new Date(start_time);
    if (end_time !== undefined) event.end_time = new Date(end_time);
    if (location !== undefined) event.location = location;
    if (type !== undefined) event.type = type;
    if (max_capacity !== undefined) event.max_capacity = max_capacity === null ? null : Number(max_capacity);

    await event.save();
    res.status(200).json(event);
  } catch (err) {
    next(err);
  }
}

// Cancela (elimina) um evento existente, incluindo os registos que dele
// dependem — não há eliminação em cascata configurada na base de dados,
// por isso é feita aqui, de forma explícita.
export async function deleteEvent(req: Request, res: Response, next: NextFunction) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) throw new ApiError(404, 'Evento não encontrado');
    if (req.user!.role !== 'admin' && event.team_id !== req.user!.team_id) {
      throw new ApiError(403, 'Só podes cancelar eventos da tua equipa');
    }

    await Attendance.destroy({ where: { event_id: event.id } });
    await SavedEvent.destroy({ where: { event_id: event.id } });
    await GameStat.destroy({ where: { event_id: event.id } });
    await event.destroy();

    res.status(200).json({ message: 'Evento cancelado com sucesso' });
  } catch (err) {
    next(err);
  }
}

export async function setAttendance(req: Request, res: Response, next: NextFunction) {
  try {
    const eventId = Number(req.params.id);
    const { status } = req.body;
    if (!['pending', 'present', 'absent'].includes(status)) {
      throw new ApiError(400, 'status deve ser pending, present ou absent');
    }
    const event = await Event.findByPk(eventId);
    if (!event) throw new ApiError(404, 'Evento não encontrado');

    const userId = req.user!.id;
    let attendance = await Attendance.findOne({ where: { event_id: eventId, user_id: userId } });
    const wasPresent = attendance?.status === 'present';

    let finalStatus: string = status;
    // Se o utilizador quer confirmar presença e o evento tem lotação
    // definida, verifica se ainda há vaga — caso contrário, vai para a
    // lista de espera automaticamente.
    if (status === 'present' && event.max_capacity !== null) {
      const presentCount = await Attendance.count({ where: { event_id: eventId, status: 'present' } });
      const alreadyCountedAsPresent = wasPresent;
      const effectiveCount = alreadyCountedAsPresent ? presentCount - 1 : presentCount;
      if (effectiveCount >= event.max_capacity) {
        finalStatus = 'waitlist';
      }
    }

    if (attendance) {
      attendance.status = finalStatus as never;
      attendance.confirmed_at = new Date();
      await attendance.save();
    } else {
      attendance = await Attendance.create({
        event_id: eventId,
        user_id: userId,
        status: finalStatus as never,
        confirmed_at: new Date(),
      });
    }

    // Se alguém desiste de um lugar confirmado, promove automaticamente o
    // primeiro da lista de espera (por ordem de inscrição).
    if (wasPresent && status !== 'present' && event.max_capacity !== null) {
      const nextInLine = await Attendance.findOne({
        where: { event_id: eventId, status: 'waitlist' },
        order: [['confirmed_at', 'ASC']],
      });
      if (nextInLine) {
        nextInLine.status = 'present';
        nextInLine.confirmed_at = new Date();
        await nextInLine.save();
      }
    }

    res.status(200).json({ ...attendance.toJSON(), waitlisted: finalStatus === 'waitlist' });
  } catch (err) {
    next(err);
  }
}
