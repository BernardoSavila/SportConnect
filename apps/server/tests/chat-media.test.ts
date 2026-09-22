import request from 'supertest';
import { app } from '../src/app';
import { ChatMessage, Team, User } from '../src/models';
import bcrypt from 'bcryptjs';

describe('Chat com imagem/áudio', () => {
  let teamId: number;
  let token: string;

  beforeAll(async () => {
    const team = await Team.create({ name: 'Chat Media Team' });
    teamId = team.id;
    const passwordHash = await bcrypt.hash('Password123', 10);
    await User.create({
      email: 'chatuser@sportconnect.pt',
      password_hash: passwordHash,
      name: 'Chat User',
      role: 'athlete',
      team_id: teamId,
    });
    const res = await request(app).post('/auth/login').send({
      email: 'chatuser@sportconnect.pt',
      password: 'Password123',
    });
    token = res.body.token;
  });

  it('persiste e devolve uma mensagem de imagem com media_url e type', async () => {
    await ChatMessage.create({
      team_id: teamId,
      sender_id: 1,
      content: null,
      media_url: 'http://localhost:3000/uploads/foto.jpg',
      type: 'image',
      sent_at: new Date(),
    });

    const res = await request(app)
      .get(`/chat/conversations?teamId=${teamId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    const imageMsg = res.body.find((m: any) => m.type === 'image');
    expect(imageMsg).toBeDefined();
    expect(imageMsg.media_url).toContain('/uploads/foto.jpg');
  });

  it('persiste e devolve uma mensagem de áudio', async () => {
    await ChatMessage.create({
      team_id: teamId,
      sender_id: 1,
      content: null,
      media_url: 'http://localhost:3000/uploads/audio.m4a',
      type: 'audio',
      sent_at: new Date(),
    });

    const res = await request(app)
      .get(`/chat/conversations?teamId=${teamId}`)
      .set('Authorization', `Bearer ${token}`);

    const audioMsg = res.body.find((m: any) => m.type === 'audio');
    expect(audioMsg).toBeDefined();
    expect(audioMsg.media_url).toContain('/uploads/audio.m4a');
  });
});
