import request from 'supertest';
import { app } from '../src/app';
import { Team } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return res.body.token as string;
}

describe('Editar e cancelar eventos, avisos e sondagens', () => {
  let teamId: number;
  let otherTeamId: number;
  let coachToken: string;
  let athleteToken: string;
  let otherCoachToken: string;

  beforeAll(async () => {
    const team = await Team.create({ name: 'Equipa Edição', description: 'x' });
    teamId = team.id;
    coachToken = await registerAndLogin('coach-edit@sportconnect.pt', 'coach', teamId);
    athleteToken = await registerAndLogin('athlete-edit@sportconnect.pt', 'athlete', teamId);

    const otherTeam = await Team.create({ name: 'Outra Equipa', description: 'x' });
    otherTeamId = otherTeam.id;
    otherCoachToken = await registerAndLogin('coach-outra@sportconnect.pt', 'coach', otherTeamId);
  });

  // ---------------- Eventos ----------------
  describe('Eventos', () => {
    let eventId: number;

    beforeEach(async () => {
      const res = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${coachToken}`)
        .send({
          team_id: teamId,
          title: 'Treino de terça',
          start_time: '2026-09-08T18:00:00Z',
          end_time: '2026-09-08T19:30:00Z',
          type: 'training',
        });
      eventId = res.body.id;
    });

    it('permite ao treinador editar o evento', async () => {
      const res = await request(app)
        .patch(`/events/${eventId}`)
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ title: 'Treino de terça (adiado)', location: 'Campo 2' });

      expect(res.status).toBe(200);
      expect(res.body.title).toBe('Treino de terça (adiado)');
      expect(res.body.location).toBe('Campo 2');
    });

    it('impede um atleta de editar o evento', async () => {
      const res = await request(app)
        .patch(`/events/${eventId}`)
        .set('Authorization', `Bearer ${athleteToken}`)
        .send({ title: 'Alterado pelo atleta' });
      expect(res.status).toBe(403);
    });

    it('impede um treinador de outra equipa de editar o evento', async () => {
      const res = await request(app)
        .patch(`/events/${eventId}`)
        .set('Authorization', `Bearer ${otherCoachToken}`)
        .send({ title: 'Alterado por outro treinador' });
      expect(res.status).toBe(403);
    });

    it('permite ao treinador cancelar (eliminar) o evento', async () => {
      const del = await request(app).delete(`/events/${eventId}`).set('Authorization', `Bearer ${coachToken}`);
      expect(del.status).toBe(200);

      const get = await request(app).get(`/events/${eventId}`).set('Authorization', `Bearer ${coachToken}`);
      expect(get.status).toBe(404);
    });

    it('impede um atleta de cancelar o evento', async () => {
      const res = await request(app).delete(`/events/${eventId}`).set('Authorization', `Bearer ${athleteToken}`);
      expect(res.status).toBe(403);
    });

    it('cancelar um evento remove também as presenças associadas', async () => {
      await request(app)
        .post(`/events/${eventId}/attendance`)
        .set('Authorization', `Bearer ${athleteToken}`)
        .send({ status: 'present' });

      const del = await request(app).delete(`/events/${eventId}`).set('Authorization', `Bearer ${coachToken}`);
      expect(del.status).toBe(200);
    });
  });

  // ---------------- Publicações (Feed) ----------------
  describe('Publicações do feed', () => {
    let postId: number;

    beforeEach(async () => {
      const res = await request(app)
        .post('/posts')
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ team_id: teamId, content: 'Aviso original' });
      postId = res.body.id;
    });

    it('permite ao treinador editar a publicação', async () => {
      const res = await request(app)
        .patch(`/posts/${postId}`)
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ content: 'Aviso corrigido' });

      expect(res.status).toBe(200);
      expect(res.body.content).toBe('Aviso corrigido');
    });

    it('rejeita editar a publicação com conteúdo vazio', async () => {
      const res = await request(app)
        .patch(`/posts/${postId}`)
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ content: '' });
      expect(res.status).toBe(400);
    });

    it('impede um atleta de editar a publicação', async () => {
      const res = await request(app)
        .patch(`/posts/${postId}`)
        .set('Authorization', `Bearer ${athleteToken}`)
        .send({ content: 'Alterado pelo atleta' });
      expect(res.status).toBe(403);
    });

    it('permite ao treinador eliminar a publicação', async () => {
      const del = await request(app).delete(`/posts/${postId}`).set('Authorization', `Bearer ${coachToken}`);
      expect(del.status).toBe(200);

      const feed = await request(app)
        .get(`/feed?teamId=${teamId}`)
        .set('Authorization', `Bearer ${coachToken}`);
      expect(feed.body.find((p: { id: number }) => p.id === postId)).toBeUndefined();
    });

    it('impede um treinador de outra equipa de eliminar a publicação', async () => {
      const res = await request(app).delete(`/posts/${postId}`).set('Authorization', `Bearer ${otherCoachToken}`);
      expect(res.status).toBe(403);
    });
  });

  // ---------------- Sondagens ----------------
  describe('Sondagens', () => {
    let pollId: number;
    let optionIds: number[];

    beforeEach(async () => {
      const res = await request(app)
        .post('/polls')
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ team_id: teamId, question: 'Manhã ou tarde?', options: ['Manhã', 'Tarde'] });
      pollId = res.body.id;
      optionIds = res.body.options.map((o: { id: number }) => o.id);
    });

    it('permite ao treinador editar a pergunta antes de haver votos', async () => {
      const res = await request(app)
        .patch(`/polls/${pollId}`)
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ question: 'Manhã, tarde ou noite?' });
      expect(res.status).toBe(200);
      expect(res.body.question).toBe('Manhã, tarde ou noite?');
    });

    it('permite ao treinador substituir as opções antes de haver votos', async () => {
      const res = await request(app)
        .patch(`/polls/${pollId}`)
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ options: ['Sábado', 'Domingo'] });
      expect(res.status).toBe(200);
      expect(res.body.options.map((o: { text: string }) => o.text).sort()).toEqual(['Domingo', 'Sábado']);
    });

    it('impede alterar as opções depois de já existir um voto', async () => {
      await request(app)
        .post(`/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${athleteToken}`)
        .send({ option_id: optionIds[0] });

      const res = await request(app)
        .patch(`/polls/${pollId}`)
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ options: ['Nova opção A', 'Nova opção B'] });
      expect(res.status).toBe(400);
    });

    it('continua a permitir editar a pergunta mesmo depois de haver votos', async () => {
      await request(app)
        .post(`/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${athleteToken}`)
        .send({ option_id: optionIds[0] });

      const res = await request(app)
        .patch(`/polls/${pollId}`)
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ question: 'Pergunta atualizada' });
      expect(res.status).toBe(200);
      expect(res.body.question).toBe('Pergunta atualizada');
    });

    it('impede um atleta de editar a sondagem', async () => {
      const res = await request(app)
        .patch(`/polls/${pollId}`)
        .set('Authorization', `Bearer ${athleteToken}`)
        .send({ question: 'Alterado pelo atleta' });
      expect(res.status).toBe(403);
    });

    it('permite ao treinador eliminar a sondagem', async () => {
      const del = await request(app).delete(`/polls/${pollId}`).set('Authorization', `Bearer ${coachToken}`);
      expect(del.status).toBe(200);

      const list = await request(app).get(`/polls?teamId=${teamId}`).set('Authorization', `Bearer ${coachToken}`);
      expect(list.body.find((p: { id: number }) => p.id === pollId)).toBeUndefined();
    });

    it('permite eliminar uma sondagem mesmo depois de ter votos', async () => {
      await request(app)
        .post(`/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${athleteToken}`)
        .send({ option_id: optionIds[0] });

      const del = await request(app).delete(`/polls/${pollId}`).set('Authorization', `Bearer ${coachToken}`);
      expect(del.status).toBe(200);
    });
  });
});
