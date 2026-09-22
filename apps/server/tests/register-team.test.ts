import request from 'supertest';
import { app } from '../src/app';

describe('Registo com criação de equipa nova', () => {
  it('cria uma equipa nova e o utilizador fica como treinador dela', async () => {
    const res = await request(app).post('/auth/register').send({
      email: 'novacoach@sportconnect.pt',
      password: 'Password123',
      name: 'Nova Treinadora',
      team_name: 'Equipa Recém-Criada',
    });

    expect(res.status).toBe(201);
    expect(res.body.user.role).toBe('coach');
    expect(res.body.team).toBeDefined();
    expect(res.body.team.name).toBe('Equipa Recém-Criada');
    expect(res.body.team.invite_code).toMatch(/^[A-Z0-9]{6}$/);
    expect(res.body.user.team_id).toBe(res.body.team.id);
  });

  it('força role=coach mesmo que o pedido peça athlete', async () => {
    const res = await request(app).post('/auth/register').send({
      email: 'forcandocoach@sportconnect.pt',
      password: 'Password123',
      name: 'Tentativa Atleta',
      role: 'athlete',
      team_name: 'Outra Equipa',
    });
    expect(res.status).toBe(201);
    expect(res.body.user.role).toBe('coach');
  });

  it('rejeita nome de equipa vazio', async () => {
    const res = await request(app).post('/auth/register').send({
      email: 'semnome@sportconnect.pt',
      password: 'Password123',
      name: 'Sem Nome',
      team_name: '   ',
    });
    expect(res.status).toBe(400);
  });

  it('rejeita enviar team_code e team_name ao mesmo tempo', async () => {
    const res = await request(app).post('/auth/register').send({
      email: 'ambos@sportconnect.pt',
      password: 'Password123',
      name: 'Ambos',
      team_code: 'SPORT1',
      team_name: 'Conflito',
    });
    expect(res.status).toBe(400);
  });

  it('o código gerado é sempre único entre equipas diferentes', async () => {
    const a = await request(app).post('/auth/register').send({
      email: 'equipaA@sportconnect.pt',
      password: 'Password123',
      name: 'Coach A',
      team_name: 'Equipa A',
    });
    const b = await request(app).post('/auth/register').send({
      email: 'equipaB@sportconnect.pt',
      password: 'Password123',
      name: 'Coach B',
      team_name: 'Equipa B',
    });
    expect(a.body.team.invite_code).not.toBe(b.body.team.invite_code);
  });
});
