import { Request, Response, NextFunction } from 'express';
import { Event } from '../models';
import { ApiError } from '../middleware/error';

function toIcsDate(date: Date): string {
  return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
}

function escapeIcsText(text: string): string {
  return text.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n');
}

// Gera um ficheiro .ics para o evento — abre diretamente na app de
// calendário do telemóvel (Google Calendar, Apple Calendar, etc.).
export async function generateIcs(req: Request, res: Response, next: NextFunction) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) throw new ApiError(404, 'Evento não encontrado');

    const ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//SportConnect//PT',
      'BEGIN:VEVENT',
      `UID:sportconnect-event-${event.id}@sportconnect.pt`,
      `DTSTAMP:${toIcsDate(new Date())}`,
      `DTSTART:${toIcsDate(new Date(event.start_time))}`,
      `DTEND:${toIcsDate(new Date(event.end_time))}`,
      `SUMMARY:${escapeIcsText(event.title)}`,
      event.location ? `LOCATION:${escapeIcsText(event.location)}` : '',
      event.description ? `DESCRIPTION:${escapeIcsText(event.description)}` : '',
      'END:VEVENT',
      'END:VCALENDAR',
    ]
      .filter(Boolean)
      .join('\r\n');

    res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="evento-${event.id}.ics"`);
    res.status(200).send(ics);
  } catch (err) {
    next(err);
  }
}
