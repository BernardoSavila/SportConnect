import request from 'supertest';
import { app } from '../src/app';
import { Team } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return { token: res.body.token as string, id: res.body.user.id as number };
}

describe('Novas funcionalidades', () => {
  let team: Team;
  let coach: { token: string; id: number };
  let athlete: { token: string; id: number };

  beforeAll(async () => {
    team = await Team.create({ name: 'Novas Funcionalidades FC' });
    coach = await registerAndLogin('coach6@sportconnect.pt', 'coach', team.id);
    athlete = await registerAndLogin('athlete6@sportconnect.pt', 'athlete', team.id);
  });

  describe('Código de convite de equipa', () => {
    it('a equipa recebe um invite_code automaticamente', () => {
      expect(team.invite_code).toBeDefined();
      expect(team.invite_code.length).toBeGreaterThanOrEqual(6);
    });

    it('permite consultar a equipa pelo código', async () => {
      const res = await request(app).get(`/teams/by-code/${team.invite_code}`);
      expect(res.status).toBe(200);
      expect(res.body.id).toBe(team.id);
    });

    it('rejeita código inválido', async () => {
      const res = await request(app).get('/teams/by-code/NAOEXISTE');
      expect(res.status).toBe(404);
    });

    it('regista um utilizador diretamente pelo team_code', async () => {
      const res = await request(app).post('/auth/register').send({
        email: 'viacodigo@sportconnect.pt',
        password: 'Password123',
        name: 'Via Código',
        team_code: team.invite_code,
      });
      expect(res.status).toBe(201);
      expect(res.body.user.team_id).toBe(team.id);
    });
  });

  describe('Estatísticas de assiduidade', () => {
    it('calcula a percentagem corretamente', async () => {
      const eventRes = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({
          team_id: team.id,
          title: 'Treino Stats',
          start_time: '2026-09-05T18:00:00Z',
          end_time: '2026-09-05T19:00:00Z',
          type: 'training',
        });
      const eventId = eventRes.body.id;
      await request(app)
        .post(`/events/${eventId}/attendance`)
        .set('Authorization', `Bearer ${athlete.token}`)
        .send({ status: 'present' });

      const res = await request(app)
        .get(`/users/${athlete.id}/attendance-stats`)
        .set('Authorization', `Bearer ${athlete.token}`);
      expect(res.status).toBe(200);
      expect(res.body.percentage).toBe(100);
      expect(res.body.present).toBeGreaterThanOrEqual(1);
    });
  });

  describe('Eventos recorrentes', () => {
    it('cria uma ocorrência por cada dia da semana indicado', async () => {
      const res = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({
          team_id: team.id,
          title: 'Treino Recorrente',
          start_time: '2026-09-01T18:00:00Z', // terça-feira
          end_time: '2026-09-01T19:30:00Z',
          type: 'training',
          recurrence: { days_of_week: [2], until: '2026-09-22T00:00:00Z' }, // terças
        });
      expect(res.status).toBe(201);
      expect(res.body.count).toBeGreaterThanOrEqual(3);
      expect(Array.isArray(res.body.events)).toBe(true);
    });
  });

  describe('Exportar evento (.ics)', () => {
    it('devolve um ficheiro .ics válido', async () => {
      const eventRes = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({
          team_id: team.id,
          title: 'Jogo Exportável',
          start_time: '2026-09-10T15:00:00Z',
          end_time: '2026-09-10T16:30:00Z',
          type: 'match',
        });
      const eventId = eventRes.body.id;

      const res = await request(app).get(`/events/${eventId}/ics`).set('Authorization', `Bearer ${coach.token}`);
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('text/calendar');
      expect(res.text).toContain('BEGIN:VCALENDAR');
      expect(res.text).toContain('SUMMARY:Jogo Exportável');
    });
  });

  describe('Sondagens', () => {
    it('cria uma sondagem, vota, e reflete o resultado', async () => {
      const createRes = await request(app)
        .post('/polls')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({ team_id: team.id, question: 'Terça ou quarta?', options: ['Terça', 'Quarta'] });
      expect(createRes.status).toBe(201);
      const pollId = createRes.body.id;
      const optionId = createRes.body.options[0].id;

      const voteRes = await request(app)
        .post(`/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${athlete.token}`)
        .send({ option_id: optionId });
      expect(voteRes.status).toBe(200);
      expect(voteRes.body.options.find((o: any) => o.id === optionId).votes).toBe(1);
      expect(voteRes.body.my_vote).toBe(optionId);
    });

    it('impede atleta de criar sondagem', async () => {
      const res = await request(app)
        .post('/polls')
        .set('Authorization', `Bearer ${athlete.token}`)
        .send({ team_id: team.id, question: 'X?', options: ['A', 'B'] });
      expect(res.status).toBe(403);
    });
  });

  describe('Estatísticas por jogo', () => {
    it('regista e agrega estatísticas de carreira', async () => {
      const eventRes = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coach.token}`)
        .send({
          team_id: team.id,
          title: 'Jogo com Stats',
          start_time: '2026-09-12T15:00:00Z',
          end_time: '2026-09-12T16:30:00Z',
          type: 'match',
        });
      const eventId = eventRes.body.id;

      const statRes = await request(app)
        .post(`/events/${eventId}/stats`)
        .set('Authorization', `Bearer ${coach.token}`)
        .send({ user_id: athlete.id, goals: 2, assists: 1, minutes_played: 60 });
      expect(statRes.status).toBe(200);
      expect(statRes.body.goals).toBe(2);

      const careerRes = await request(app)
        .get(`/users/${athlete.id}/career-stats`)
        .set('Authorization', `Bearer ${athlete.token}`);
      expect(careerRes.status).toBe(200);
      expect(careerRes.body.goals).toBeGreaterThanOrEqual(2);
      expect(careerRes.body.games).toBeGreaterThanOrEqual(1);
    });
  });

  describe('Relatório mensal (PDF)', () => {
    it('gera um PDF válido', async () => {
      const res = await request(app)
        .get(`/reports/monthly?teamId=${team.id}&month=9&year=2026`)
        .set('Authorization', `Bearer ${coach.token}`);
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('application/pdf');
      // Um PDF válido começa sempre por esta assinatura de ficheiro.
      expect(res.body.slice(0, 4).toString()).toBe('%PDF');
    });
  });
});
