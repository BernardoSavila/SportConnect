import request from 'supertest';
import { app } from '../src/app';
import { Team } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return res.body.token as string;
}

describe('Events & Attendance', () => {
  let teamId: number;
  let coachToken: string;
  let athleteToken: string;

  beforeAll(async () => {
    const team = await Team.create({ name: 'Test Team', description: 'x' });
    teamId = team.id;
    coachToken = await registerAndLogin('coach2@sportconnect.pt', 'coach', teamId);
    athleteToken = await registerAndLogin('athlete2@sportconnect.pt', 'athlete', teamId);
  });

  it('impede atleta de criar evento', async () => {
    const res = await request(app)
      .post('/events')
      .set('Authorization', `Bearer ${athleteToken}`)
      .send({
        team_id: teamId,
        title: 'Treino',
        start_time: '2026-08-01T18:00:00Z',
        end_time: '2026-08-01T19:00:00Z',
        type: 'training',
      });
    expect(res.status).toBe(403);
  });

  it('permite coach criar evento e atleta confirmar presença', async () => {
    const createRes = await request(app)
      .post('/events')
      .set('Authorization', `Bearer ${coachToken}`)
      .send({
        team_id: teamId,
        title: 'Treino Táctico',
        start_time: '2026-08-01T18:00:00Z',
        end_time: '2026-08-01T19:30:00Z',
        location: 'Campo A',
        type: 'training',
      });
    expect(createRes.status).toBe(201);
    const eventId = createRes.body.id;

    const listRes = await request(app).get(`/events?teamId=${teamId}`).set('Authorization', `Bearer ${athleteToken}`);
    expect(listRes.status).toBe(200);
    expect(listRes.body.length).toBeGreaterThan(0);

    const attendanceRes = await request(app)
      .post(`/events/${eventId}/attendance`)
      .set('Authorization', `Bearer ${athleteToken}`)
      .send({ status: 'present' });
    expect(attendanceRes.status).toBe(200);
    expect(attendanceRes.body.status).toBe('present');
  });

  it('rejeita pedidos sem token', async () => {
    const res = await request(app).get(`/events?teamId=${teamId}`);
    expect(res.status).toBe(401);
  });
});
