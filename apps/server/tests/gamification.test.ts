import request from 'supertest';
import { app } from '../src/app';
import { Team } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return { token: res.body.token as string, id: res.body.user.id as number };
}

describe('Team members & Achievements (gamificação)', () => {
  let teamId: number;
  let coach: { token: string; id: number };
  let athlete: { token: string; id: number };

  beforeAll(async () => {
    const team = await Team.create({ name: 'Gamification Team', description: 'x' });
    teamId = team.id;
    coach = await registerAndLogin('coach4@sportconnect.pt', 'coach', teamId);
    athlete = await registerAndLogin('athlete4@sportconnect.pt', 'athlete', teamId);
  });

  it('lista os membros da equipa', async () => {
    const res = await request(app).get(`/teams/${teamId}/members`).set('Authorization', `Bearer ${coach.token}`);
    expect(res.status).toBe(200);
    expect(res.body.length).toBe(2);
  });

  it('impede atleta de atribuir pontos', async () => {
    const res = await request(app)
      .post('/achievements')
      .set('Authorization', `Bearer ${athlete.token}`)
      .send({ user_id: athlete.id, type: 'MVP', points: 10 });
    expect(res.status).toBe(403);
  });

  it('permite coach atribuir pontos a atleta da sua equipa', async () => {
    const res = await request(app)
      .post('/achievements')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({ user_id: athlete.id, type: 'Assiduidade', points: 15 });
    expect(res.status).toBe(201);
    expect(res.body.points).toBe(15);

    const ranking = await request(app)
      .get(`/ranking?teamId=${teamId}`)
      .set('Authorization', `Bearer ${coach.token}`);
    const entry = ranking.body.find((r: any) => r.user_id === athlete.id);
    expect(entry.total_points).toBe(15);
  });

  it('impede coach de atribuir pontos a atleta de outra equipa', async () => {
    const otherTeam = await Team.create({ name: 'Other Team' });
    const outsider = await registerAndLogin('outsider@sportconnect.pt', 'athlete', otherTeam.id);
    const res = await request(app)
      .post('/achievements')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({ user_id: outsider.id, type: 'MVP', points: 10 });
    expect(res.status).toBe(403);
  });
});
