import request from 'supertest';
import { app } from '../src/app';
import { Team } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return { token: res.body.token as string, id: res.body.user.id as number };
}

describe('Ficha de jogador e password', () => {
  let teamId: number;
  let athlete: { token: string; id: number };

  beforeAll(async () => {
    const team = await Team.create({ name: 'Profile Team' });
    teamId = team.id;
    athlete = await registerAndLogin('profiletest@sportconnect.pt', 'athlete', teamId);
  });

  describe('PATCH /users/me/profile', () => {
    it('atualiza nome, posição e número de camisola', async () => {
      const res = await request(app)
        .patch('/users/me/profile')
        .set('Authorization', `Bearer ${athlete.token}`)
        .send({ name: 'Nome Novo', position: 'Avançado', jersey_number: 9 });
      expect(res.status).toBe(200);
      expect(res.body.name).toBe('Nome Novo');
      expect(res.body.position).toBe('Avançado');
      expect(res.body.jersey_number).toBe(9);
    });

    it('os dados aparecem depois no perfil público', async () => {
      const res = await request(app).get(`/users/${athlete.id}`).set('Authorization', `Bearer ${athlete.token}`);
      expect(res.body.position).toBe('Avançado');
      expect(res.body.jersey_number).toBe(9);
    });

    it('rejeita número de camisola inválido', async () => {
      const res = await request(app)
        .patch('/users/me/profile')
        .set('Authorization', `Bearer ${athlete.token}`)
        .send({ jersey_number: 1000 });
      expect(res.status).toBe(400);
    });

    it('rejeita nome vazio', async () => {
      const res = await request(app).patch('/users/me/profile').set('Authorization', `Bearer ${athlete.token}`).send({ name: '   ' });
      expect(res.status).toBe(400);
    });
  });

  describe('PATCH /users/me/password', () => {
    it('muda a password com sucesso', async () => {
      const res = await request(app)
        .patch('/users/me/password')
        .set('Authorization', `Bearer ${athlete.token}`)
        .send({ current_password: 'Password123', new_password: 'NovaPassword456' });
      expect(res.status).toBe(200);

      // confirma que já dá para fazer login com a password nova
      const login = await request(app).post('/auth/login').send({ email: 'profiletest@sportconnect.pt', password: 'NovaPassword456' });
      expect(login.status).toBe(200);
    });

    it('rejeita se a password atual estiver errada', async () => {
      const res = await request(app)
        .patch('/users/me/password')
        .set('Authorization', `Bearer ${athlete.token}`)
        .send({ current_password: 'PasswordErrada', new_password: 'OutraPassword789' });
      expect(res.status).toBe(401);
    });

    it('rejeita password nova demasiado curta', async () => {
      const res = await request(app)
        .patch('/users/me/password')
        .set('Authorization', `Bearer ${athlete.token}`)
        .send({ current_password: 'NovaPassword456', new_password: 'curta' });
      expect(res.status).toBe(400);
    });
  });
});
