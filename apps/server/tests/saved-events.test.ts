import request from 'supertest';
import { app } from '../src/app';
import { Team } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return { token: res.body.token as string, id: res.body.user.id as number };
}

describe('Eventos guardados no calendário pessoal', () => {
  let teamId: number;
  let coach: { token: string; id: number };
  let athlete: { token: string; id: number };

  beforeAll(async () => {
    const team = await Team.create({ name: 'Saved Events Team' });
    teamId = team.id;
    coach = await registerAndLogin('coach8@sportconnect.pt', 'coach', teamId);
    athlete = await registerAndLogin('athlete8@sportconnect.pt', 'athlete', teamId);
  });

  it('lista vazia quando não há nada guardado', async () => {
    const res = await request(app).get('/events/saved').set('Authorization', `Bearer ${athlete.token}`);
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('guarda um evento e depois aparece na lista', async () => {
    const eventRes = await request(app)
      .post('/events')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({
        team_id: teamId,
        title: 'Treino para guardar',
        start_time: '2026-11-01T18:00:00Z',
        end_time: '2026-11-01T19:00:00Z',
        type: 'training',
      });
    const eventId = eventRes.body.id;

    const saveRes = await request(app)
      .post(`/events/${eventId}/save`)
      .set('Authorization', `Bearer ${athlete.token}`);
    expect(saveRes.status).toBe(200);
    expect(saveRes.body.saved).toBe(true);

    const listRes = await request(app).get('/events/saved').set('Authorization', `Bearer ${athlete.token}`);
    expect(listRes.status).toBe(200);
    expect(listRes.body.length).toBe(1);
    expect(listRes.body[0].id).toBe(eventId);
  });

  it('chamar de novo remove o evento (toggle)', async () => {
    const eventRes = await request(app)
      .post('/events')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({
        team_id: teamId,
        title: 'Treino toggle',
        start_time: '2026-11-02T18:00:00Z',
        end_time: '2026-11-02T19:00:00Z',
        type: 'training',
      });
    const eventId = eventRes.body.id;

    const first = await request(app).post(`/events/${eventId}/save`).set('Authorization', `Bearer ${athlete.token}`);
    expect(first.body.saved).toBe(true);

    const second = await request(app).post(`/events/${eventId}/save`).set('Authorization', `Bearer ${athlete.token}`);
    expect(second.body.saved).toBe(false);

    const listRes = await request(app).get('/events/saved').set('Authorization', `Bearer ${athlete.token}`);
    expect(listRes.body.find((e: any) => e.id === eventId)).toBeUndefined();
  });

  it('guardar é próprio de cada utilizador — não aparece na lista de outro', async () => {
    const eventRes = await request(app)
      .post('/events')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({
        team_id: teamId,
        title: 'Treino só do treinador',
        start_time: '2026-11-03T18:00:00Z',
        end_time: '2026-11-03T19:00:00Z',
        type: 'training',
      });
    const eventId = eventRes.body.id;

    await request(app).post(`/events/${eventId}/save`).set('Authorization', `Bearer ${coach.token}`);

    const athleteList = await request(app).get('/events/saved').set('Authorization', `Bearer ${athlete.token}`);
    expect(athleteList.body.find((e: any) => e.id === eventId)).toBeUndefined();

    const coachList = await request(app).get('/events/saved').set('Authorization', `Bearer ${coach.token}`);
    expect(coachList.body.find((e: any) => e.id === eventId)).toBeDefined();
  });

  it('rejeita pedidos sem autenticação', async () => {
    const res = await request(app).get('/events/saved');
    expect(res.status).toBe(401);
  });
});
