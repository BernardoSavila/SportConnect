import request from 'supertest';
import path from 'path';
import fs from 'fs';
import { app } from '../src/app';

describe('Media upload', () => {
  const tmpImagePath = path.join(__dirname, 'fixture.png');

  beforeAll(() => {
    // 1x1 pixel PNG válido, em base64, só para teste de upload.
    const base64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    fs.writeFileSync(tmpImagePath, Buffer.from(base64, 'base64'));
  });

  afterAll(() => {
    fs.unlinkSync(tmpImagePath);
  });

  async function getToken() {
    await request(app).post('/auth/register').send({
      email: 'uploader@sportconnect.pt',
      password: 'Password123',
      name: 'Uploader',
    });
    const res = await request(app).post('/auth/login').send({
      email: 'uploader@sportconnect.pt',
      password: 'Password123',
    });
    return res.body.token as string;
  }

  it('rejeita upload sem autenticação', async () => {
    const res = await request(app).post('/media/upload').attach('file', tmpImagePath);
    expect(res.status).toBe(401);
  });

  it('aceita upload de imagem autenticado e devolve URL', async () => {
    const token = await getToken();
    const res = await request(app)
      .post('/media/upload')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', tmpImagePath);
    expect(res.status).toBe(201);
    expect(res.body.url).toContain('/uploads/');
  });
});
