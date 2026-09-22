import request from 'supertest';
import { app } from '../src/app';
import { Team } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return { token: res.body.token as string, id: res.body.user.id as number };
}

describe('Likes, avatar e roster completo', () => {
  let teamId: number;
  let coach: { token: string; id: number };
  let athlete1: { token: string; id: number };
  let athlete2: { token: string; id: number };

  beforeAll(async () => {
    const team = await Team.create({ name: 'Extra Features Team' });
    teamId = team.id;
    coach = await registerAndLogin('coach5@sportconnect.pt', 'coach', teamId);
    athlete1 = await registerAndLogin('athlete5a@sportconnect.pt', 'athlete', teamId);
    athlete2 = await registerAndLogin('athlete5b@sportconnect.pt', 'athlete', teamId);
  });

  it('cria post já com likes_count 0 e liked_by_me false', async () => {
    const res = await request(app)
      .post('/posts')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({ team_id: teamId, content: 'Aviso com likes' });
    expect(res.status).toBe(201);
    expect(res.body.likes_count).toBe(0);
    expect(res.body.liked_by_me).toBe(false);
  });

  it('permite dar e retirar like a um post', async () => {
    const postRes = await request(app)
      .post('/posts')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({ team_id: teamId, content: 'Post para gostar' });
    const postId = postRes.body.id;

    const likeRes = await request(app)
      .post(`/posts/${postId}/like`)
      .set('Authorization', `Bearer ${athlete1.token}`);
    expect(likeRes.status).toBe(200);
    expect(likeRes.body.liked_by_me).toBe(true);
    expect(likeRes.body.likes_count).toBe(1);

    const unlikeRes = await request(app)
      .post(`/posts/${postId}/like`)
      .set('Authorization', `Bearer ${athlete1.token}`);
    expect(unlikeRes.body.liked_by_me).toBe(false);
    expect(unlikeRes.body.likes_count).toBe(0);
  });

  it('feed reflete likes_count e liked_by_me corretamente por utilizador', async () => {
    const postRes = await request(app)
      .post('/posts')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({ team_id: teamId, content: 'Post partilhado' });
    const postId = postRes.body.id;
    await request(app).post(`/posts/${postId}/like`).set('Authorization', `Bearer ${athlete1.token}`);

    const feedForAthlete1 = await request(app).get(`/feed?teamId=${teamId}`).set('Authorization', `Bearer ${athlete1.token}`);
    const feedForAthlete2 = await request(app).get(`/feed?teamId=${teamId}`).set('Authorization', `Bearer ${athlete2.token}`);

    const post1 = feedForAthlete1.body.find((p: any) => p.id === postId);
    const post2 = feedForAthlete2.body.find((p: any) => p.id === postId);
    expect(post1.liked_by_me).toBe(true);
    expect(post2.liked_by_me).toBe(false);
    expect(post1.likes_count).toBe(1);
  });

  it('atualiza o avatar do próprio utilizador', async () => {
    const res = await request(app)
      .patch('/users/me/avatar')
      .set('Authorization', `Bearer ${athlete1.token}`)
      .send({ avatar_url: 'http://localhost:3000/uploads/avatar123.jpg' });
    expect(res.status).toBe(200);
    expect(res.body.avatar_url).toContain('avatar123.jpg');

    const profile = await request(app)
      .get(`/users/${athlete1.id}`)
      .set('Authorization', `Bearer ${athlete1.token}`);
    expect(profile.body.avatar_url).toContain('avatar123.jpg');
  });

  it('devolve roster completo do evento com pending por omissão', async () => {
    const eventRes = await request(app)
      .post('/events')
      .set('Authorization', `Bearer ${coach.token}`)
      .send({
        team_id: teamId,
        title: 'Treino Roster',
        start_time: '2026-09-01T18:00:00Z',
        end_time: '2026-09-01T19:00:00Z',
        type: 'training',
      });
    const eventId = eventRes.body.id;

    // Apenas athlete1 confirma; athlete2 fica pendente por omissão.
    await request(app)
      .post(`/events/${eventId}/attendance`)
      .set('Authorization', `Bearer ${athlete1.token}`)
      .send({ status: 'present' });

    const detail = await request(app)
      .get(`/events/${eventId}`)
      .set('Authorization', `Bearer ${coach.token}`);

    expect(detail.status).toBe(200);
    const roster = detail.body.attendance;
    const a1 = roster.find((r: any) => r.user_id === athlete1.id);
    const a2 = roster.find((r: any) => r.user_id === athlete2.id);
    expect(a1.status).toBe('present');
    expect(a2.status).toBe('pending');
  });
});
