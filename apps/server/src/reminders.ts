import cron from 'node-cron';
import { Op } from 'sequelize';
import { Event, Attendance, User, ChatMessage } from './models';

// Eventos para os quais já foi enviado um lembrete nesta execução do
// servidor — evita spam repetido. Simplificação razoável para um projeto
// académico (reinicia ao reiniciar o servidor); numa versão de produção
// isto passaria para uma coluna `reminder_sent_at` na tabela events.
const remindedEventIds = new Set<number>();

// Verifica eventos nas próximas 24h com atletas que ainda não confirmaram
// presença, e publica um lembrete automático no chat da equipa.
export async function checkAndSendReminders(): Promise<number> {
  const now = new Date();
  const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const upcomingEvents = await Event.findAll({
    where: { start_time: { [Op.gte]: now, [Op.lte]: in24h } },
  });

  let remindersSent = 0;

  for (const event of upcomingEvents) {
    if (remindedEventIds.has(event.id)) continue;

    const athletes = await User.findAll({ where: { team_id: event.team_id, role: 'athlete' } });
    const attendance = await Attendance.findAll({ where: { event_id: event.id } });
    const decidedIds = new Set(attendance.filter((a) => a.status !== 'pending').map((a) => a.user_id));
    const pendingCount = athletes.filter((a) => !decidedIds.has(a.id)).length;

    if (pendingCount === 0) continue;

    const dateStr = new Date(event.start_time).toLocaleString('pt-PT', {
      weekday: 'long',
      hour: '2-digit',
      minute: '2-digit',
    });

    await ChatMessage.create({
      team_id: event.team_id,
      sender_id: event.created_by,
      content: `⏰ Lembrete: ${pendingCount} atleta${pendingCount > 1 ? 's' : ''} ainda ${
        pendingCount > 1 ? 'não confirmaram' : 'não confirmou'
      } presença em "${event.title}" (${dateStr}).`,
      type: 'text',
      sent_at: new Date(),
    });

    remindedEventIds.add(event.id);
    remindersSent++;
  }

  return remindersSent;
}

/// Agenda a verificação de lembretes para correr todas as horas.
/// Chamado uma vez a partir de server.ts.
export function startReminderJob() {
  cron.schedule('0 * * * *', () => {
    checkAndSendReminders().catch((err) => {
      // eslint-disable-next-line no-console
      console.error('Erro ao verificar lembretes automáticos:', err);
    });
  });
}
