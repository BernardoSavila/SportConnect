import request from 'supertest';
import { app } from '../src/app';

describe('Auth', () => {
  it('regista um novo utilizador e devolve token', async () => {
    const res = await request(app).post('/auth/register').send({
      email: 'novo@sportconnect.pt',
      password: 'Password123',
      name: 'Novo Atleta',
    });
    expect(res.status).toBe(201);
    expect(res.body.token).toBeDefined();
    expect(res.body.user.email).toBe('novo@sportconnect.pt');
  });

  it('rejeita registo duplicado', async () => {
    await request(app).post('/auth/register').send({
      email: 'dup@sportconnect.pt',
      password: 'Password123',
      name: 'Dup',
    });
    const res = await request(app).post('/auth/register').send({
      email: 'dup@sportconnect.pt',
      password: 'Password123',
      name: 'Dup',
    });
    expect(res.status).toBe(409);
  });

  it('faz login com credenciais válidas', async () => {
    await request(app).post('/auth/register').send({
      email: 'login@sportconnect.pt',
      password: 'Password123',
      name: 'Login Test',
    });
    const res = await request(app).post('/auth/login').send({
      email: 'login@sportconnect.pt',
      password: 'Password123',
    });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
  });

  it('rejeita login com password errada', async () => {
    await request(app).post('/auth/register').send({
      email: 'wrongpass@sportconnect.pt',
      password: 'Password123',
      name: 'Wrong Pass',
    });
    const res = await request(app).post('/auth/login').send({
      email: 'wrongpass@sportconnect.pt',
      password: 'ErradaPassword',
    });
    expect(res.status).toBe(401);
  });
});
