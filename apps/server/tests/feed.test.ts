import request from 'supertest';
import { app } from '../src/app';
import { Team, Achievement, User } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return { token: res.body.token as string, id: res.body.user.id as number };
}

describe('Feed & Ranking', () => {
  let teamId: number;
  let coach: { token: string; id: number };
  let athlete: { token: string; id: number };

  beforeAll(async () => {
    const team = await Team.create({ name: 'Feed Team', description: 'x' });
    teamId = team.id;
    coach = await registerAndLogin('coach3@sportconnect.pt', 'coach', teamId);
    athlete = await registerAndLogin('athlete3@sportconnect.pt', 'athlete', teamId);
    await Achievement.create({ user_id: athlete.id, type: 'Assiduidade', points: 30 });
  });

  it('permite coach publicar post e todos verem o feed', async () => {
    const postRes = await request(app)
      .post('/posts')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({ team_id: teamId, content: 'Aviso importante' });
    expect(postRes.status).toBe(201);

    const feedRes = await request(app).get(`/feed?teamId=${teamId}`).set('Authorization', `Bearer ${athlete.token}`);
    expect(feedRes.status).toBe(200);
    expect(feedRes.body[0].content).toBe('Aviso importante');
  });

  it('calcula ranking por pontos', async () => {
    const res = await request(app).get(`/ranking?teamId=${teamId}`).set('Authorization', `Bearer ${athlete.token}`);
    expect(res.status).toBe(200);
    const entry = res.body.find((r: any) => r.user_id === athlete.id);
    expect(entry.total_points).toBe(30);
  });

  it('devolve perfil de utilizador com achievements', async () => {
    const res = await request(app)
      .get(`/users/${athlete.id}`)
      .set('Authorization', `Bearer ${athlete.token}`);
    expect(res.status).toBe(200);
    expect(res.body.total_points).toBe(30);
  });
});
