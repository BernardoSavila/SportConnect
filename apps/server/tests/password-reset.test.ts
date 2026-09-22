import request from 'supertest';
import crypto from 'crypto';

jest.mock('../src/utils/mailer', () => ({
  sendPasswordResetEmail: jest.fn().mockResolvedValue(undefined),
}));

import { app } from '../src/app';
import { PasswordReset, User } from '../src/models';
import * as mailer from '../src/utils/mailer';

function hashCode(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}

async function registerUser(email: string) {
  await request(app).post('/auth/register').send({
    email,
    password: 'Password123',
    name: 'Utilizador Teste',
    team_name: `Equipa ${email}`,
  });
}

describe('Recuperação de password', () => {
  beforeEach(() => {
    (mailer.sendPasswordResetEmail as jest.Mock).mockClear();
  });

  it('cria um código de recuperação e envia o email quando o utilizador existe', async () => {
    await registerUser('recupera1@sportconnect.pt');

    const res = await request(app).post('/auth/forgot-password').send({ email: 'recupera1@sportconnect.pt' });

    expect(res.status).toBe(200);
    expect(mailer.sendPasswordResetEmail).toHaveBeenCalledTimes(1);
    expect(mailer.sendPasswordResetEmail).toHaveBeenCalledWith(
      'recupera1@sportconnect.pt',
      'Utilizador Teste',
      expect.stringMatching(/^\d{6}$/)
    );

    const user = await User.findOne({ where: { email: 'recupera1@sportconnect.pt' } });
    const reset = await PasswordReset.findOne({ where: { user_id: user!.id } });
    expect(reset).not.toBeNull();
    expect(reset!.used).toBe(false);
  });

  it('responde com sucesso mesmo para um email que não existe, sem enviar email (evita enumeração de contas)', async () => {
    const res = await request(app).post('/auth/forgot-password').send({ email: 'naoexiste@sportconnect.pt' });

    expect(res.status).toBe(200);
    expect(mailer.sendPasswordResetEmail).not.toHaveBeenCalled();
  });

  it('permite redefinir a password com o código correto, e o novo password funciona no login', async () => {
    await registerUser('recupera2@sportconnect.pt');
    await request(app).post('/auth/forgot-password').send({ email: 'recupera2@sportconnect.pt' });

    const code = (mailer.sendPasswordResetEmail as jest.Mock).mock.calls[0][2];

    const resetRes = await request(app).post('/auth/reset-password').send({
      email: 'recupera2@sportconnect.pt',
      code,
      new_password: 'NovaPassword456',
    });
    expect(resetRes.status).toBe(200);

    const loginOld = await request(app).post('/auth/login').send({
      email: 'recupera2@sportconnect.pt',
      password: 'Password123',
    });
    expect(loginOld.status).toBe(401);

    const loginNew = await request(app).post('/auth/login').send({
      email: 'recupera2@sportconnect.pt',
      password: 'NovaPassword456',
    });
    expect(loginNew.status).toBe(200);
  });

  it('rejeita um código errado', async () => {
    await registerUser('recupera3@sportconnect.pt');
    await request(app).post('/auth/forgot-password').send({ email: 'recupera3@sportconnect.pt' });

    const res = await request(app).post('/auth/reset-password').send({
      email: 'recupera3@sportconnect.pt',
      code: '000000',
      new_password: 'NovaPassword456',
    });
    expect(res.status).toBe(400);
  });

  it('rejeita reutilizar um código já usado', async () => {
    await registerUser('recupera4@sportconnect.pt');
    await request(app).post('/auth/forgot-password').send({ email: 'recupera4@sportconnect.pt' });
    const code = (mailer.sendPasswordResetEmail as jest.Mock).mock.calls[0][2];

    const first = await request(app).post('/auth/reset-password').send({
      email: 'recupera4@sportconnect.pt',
      code,
      new_password: 'NovaPassword456',
    });
    expect(first.status).toBe(200);

    const second = await request(app).post('/auth/reset-password').send({
      email: 'recupera4@sportconnect.pt',
      code,
      new_password: 'OutraPassword789',
    });
    expect(second.status).toBe(400);
  });

  it('rejeita um código expirado', async () => {
    await registerUser('recupera5@sportconnect.pt');
    await request(app).post('/auth/forgot-password').send({ email: 'recupera5@sportconnect.pt' });
    const code = (mailer.sendPasswordResetEmail as jest.Mock).mock.calls[0][2];

    const user = await User.findOne({ where: { email: 'recupera5@sportconnect.pt' } });
    await PasswordReset.update(
      { expires_at: new Date(Date.now() - 60 * 1000) },
      { where: { user_id: user!.id, code_hash: hashCode(code) } }
    );

    const res = await request(app).post('/auth/reset-password').send({
      email: 'recupera5@sportconnect.pt',
      code,
      new_password: 'NovaPassword456',
    });
    expect(res.status).toBe(400);
  });

  it('rejeita nova password com menos de 8 caracteres', async () => {
    await registerUser('recupera6@sportconnect.pt');
    await request(app).post('/auth/forgot-password').send({ email: 'recupera6@sportconnect.pt' });
    const code = (mailer.sendPasswordResetEmail as jest.Mock).mock.calls[0][2];

    const res = await request(app).post('/auth/reset-password').send({
      email: 'recupera6@sportconnect.pt',
      code,
      new_password: '123',
    });
    expect(res.status).toBe(400);
  });
});
