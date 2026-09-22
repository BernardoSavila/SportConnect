import request from 'supertest';
import { app } from '../src/app';
import { Team, ChatMessage } from '../src/models';
import { checkAndSendReminders } from '../src/reminders';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return { token: res.body.token as string, id: res.body.user.id as number };
}

describe('Spond-like features', () => {
  let teamId: number;
  let coach: { token: string; id: number };
  let athlete1: { token: string; id: number };
  let athlete2: { token: string; id: number };
  let athlete3: { token: string; id: number };

  beforeAll(async () => {
    const team = await Team.create({ name: 'Spond Features Team' });
    teamId = team.id;
    coach = await registerAndLogin('coach7@sportconnect.pt', 'coach', teamId);
    athlete1 = await registerAndLogin('athlete7a@sportconnect.pt', 'athlete', teamId);
    athlete2 = await registerAndLogin('athlete7b@sportconnect.pt', 'athlete', teamId);
    athlete3 = await registerAndLogin('athlete7c@sportconnect.pt', 'athlete', teamId);
  });

  describe('Contactos de emergência / encarregado de educação', () => {
    it('atleta atualiza os seus próprios contactos', async () => {
      const res = await request(app)
        .patch('/users/me/contact')
        .set('Authorization', `Bearer ${athlete1.token}`)
        .send({
          guardian_name: 'Maria Costa',
          guardian_phone: '912345678',
          emergency_contact_name: 'Maria Costa',
          emergency_contact_phone: '912345678',
        });
      expect(res.status).toBe(200);
      expect(res.body.guardian_name).toBe('Maria Costa');
    });

    it('o próprio atleta e o treinador da equipa veem os contactos, mas outro atleta não', async () => {
      const selfView = await request(app).get(`/users/${athlete1.id}`).set('Authorization', `Bearer ${athlete1.token}`);
      expect(selfView.body.guardian_name).toBe('Maria Costa');

      const coachView = await request(app).get(`/users/${athlete1.id}`).set('Authorization', `Bearer ${coach.token}`);
      expect(coachView.body.guardian_name).toBe('Maria Costa');

      const peerView = await request(app).get(`/users/${athlete1.id}`).set('Authorization', `Bearer ${athlete2.token}`);
      expect(peerView.body.guardian_name).toBeUndefined();
    });
  });

  describe('Lista de espera em eventos com lotação', () => {
    it('atletas extra vão para waitlist e são promovidos quando alguém desiste', async () => {
      const eventRes = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({
          team_id: teamId,
          title: 'Treino com lotação',
          start_time: '2026-10-01T18:00:00Z',
          end_time: '2026-10-01T19:00:00Z',
          type: 'training',
          max_capacity: 2,
        });
      const eventId = eventRes.body.id;

      const r1 = await request(app)
        .post(`/events/${eventId}/attendance`)
        .set('Authorization', `Bearer ${athlete1.token}`)
        .send({ status: 'present' });
      expect(r1.body.status).toBe('present');

      const r2 = await request(app)
        .post(`/events/${eventId}/attendance`)
        .set('Authorization', `Bearer ${athlete2.token}`)
        .send({ status: 'present' });
      expect(r2.body.status).toBe('present');

      const r3 = await request(app)
        .post(`/events/${eventId}/attendance`)
        .set('Authorization', `Bearer ${athlete3.token}`)
        .send({ status: 'present' });
      expect(r3.body.status).toBe('waitlist');
      expect(r3.body.waitlisted).toBe(true);

      // athlete1 desiste -> athlete3 (waitlist) deve ser promovido
      await request(app)
        .post(`/events/${eventId}/attendance`)
        .set('Authorization', `Bearer ${athlete1.token}`)
        .send({ status: 'absent' });

      const detail = await request(app).get(`/events/${eventId}`).set('Authorization', `Bearer ${coach.token}`);
      const a3 = detail.body.attendance.find((r: any) => r.user_id === athlete3.id);
      expect(a3.status).toBe('present');
    });
  });

  describe('Duplicar evento', () => {
    it('cria uma cópia do evento numa nova data', async () => {
      const original = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({
          team_id: teamId,
          title: 'Jogo Original',
          location: 'Estádio A',
          start_time: '2026-10-05T15:00:00Z',
          end_time: '2026-10-05T16:30:00Z',
          type: 'match',
        });

      const dup = await request(app)
        .post(`/events/${original.body.id}/duplicate`)
        .set('Authorization', `Bearer ${coach.token}`)
        .send({ start_time: '2026-10-12T15:00:00Z', end_time: '2026-10-12T16:30:00Z' });

      expect(dup.status).toBe(201);
      expect(dup.body.title).toBe('Jogo Original');
      expect(dup.body.location).toBe('Estádio A');
      expect(dup.body.id).not.toBe(original.body.id);
    });

    it('impede atleta de duplicar evento', async () => {
      const eventRes = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({ team_id: teamId, title: 'X', start_time: '2026-10-06T15:00:00Z', end_time: '2026-10-06T16:00:00Z', type: 'training' });

      const res = await request(app)
        .post(`/events/${eventRes.body.id}/duplicate`)
        .set('Authorization', `Bearer ${athlete1.token}`)
        .send({ start_time: '2026-10-13T15:00:00Z', end_time: '2026-10-13T16:00:00Z' });
      expect(res.status).toBe(403);
    });
  });

  describe('Mensagens privadas (DM)', () => {
    it('lista conversas vazias quando não há mensagens', async () => {
      const res = await request(app).get('/messages/direct/conversations').set('Authorization', `Bearer ${athlete2.token}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    });

    it('devolve histórico vazio entre dois utilizadores sem mensagens', async () => {
      const res = await request(app)
        .get(`/messages/direct/${athlete2.id}`)
        .set('Authorization', `Bearer ${athlete1.token}`);
      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });
  });

  describe('Lembretes automáticos', () => {
    it('publica um lembrete no chat para evento nas próximas 24h com pendentes', async () => {
      const soon = new Date(Date.now() + 6 * 60 * 60 * 1000); // daqui a 6h
      const end = new Date(soon.getTime() + 60 * 60 * 1000);

      const eventRes = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({
          team_id: teamId,
          title: 'Treino Lembrete',
          start_time: soon.toISOString(),
          end_time: end.toISOString(),
          type: 'training',
        });
      expect(eventRes.status).toBe(201);

      const sentCount = await checkAndSendReminders();
      expect(sentCount).toBeGreaterThanOrEqual(1);

      const messages = await ChatMessage.findAll({ where: { team_id: teamId } });
      const reminder = messages.find((m) => m.content?.includes('Treino Lembrete'));
      expect(reminder).toBeDefined();
    });

    it('não repete o lembrete para o mesmo evento numa segunda chamada', async () => {
      const before = await ChatMessage.count();
      await checkAndSendReminders();
      const after = await ChatMessage.count();
      expect(after).toBe(before); // nenhum lembrete novo, já foram todos enviados
    });
  });
});
