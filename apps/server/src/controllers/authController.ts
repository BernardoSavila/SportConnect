import { Request, Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { User, Team, PasswordReset, CoachHistory, MembershipHistory } from '../models';
import { ApiError } from '../middleware/error';
import { sendPasswordResetEmail } from '../utils/mailer';

const RESET_CODE_TTL_MINUTES = 15;

function hashCode(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function signToken(user: User) {
  const secret = process.env.JWT_SECRET || 'dev-secret';
  const expiresIn = process.env.JWT_EXPIRES_IN || '7d';
  return jwt.sign({ id: user.id, role: user.role, team_id: user.team_id }, secret, { expiresIn } as jwt.SignOptions);
}

function toProfile(user: User) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    team_id: user.team_id,
    avatar_url: user.avatar_url,
    position: user.position,
    jersey_number: user.jersey_number,
  };
}

export async function register(req: Request, res: Response, next: NextFunction) {
  try {
    const { email, password, name, role, team_id, team_code, team_name } = req.body;
    if (!email || !password || !name) {
      throw new ApiError(400, 'email, password e name são obrigatórios');
    }
    if (password.length < 8) {
      throw new ApiError(400, 'password deve ter pelo menos 8 caracteres');
    }
    if (team_code && team_name) {
      throw new ApiError(400, 'Usa apenas um: código de equipa (para entrar numa já existente) ou nome (para criar uma nova)');
    }
    const existing = await User.findOne({ where: { email } });
    if (existing) {
      throw new ApiError(409, 'Email já registado');
    }

    let resolvedTeamId: number | null = team_id ?? null;
    let resolvedRole = role || 'athlete';
    let newTeam: Team | null = null;
    let isAssistantCoach = false;

    if (team_code) {
      const team = await Team.findOne({ where: { invite_code: String(team_code).toUpperCase() } });
      if (!team) throw new ApiError(400, 'Código de equipa inválido');
      resolvedTeamId = team.id;
      // Quem entra por código pode fazê-lo como atleta ou, se indicado,
      // como treinador (ex: treinador-adjunto) ou admin — mas nunca
      // ganha um papel só por o pedir, continua sujeito ao papel enviado
      // pela própria app, tal como já acontecia para 'coach'.
      if (role === 'coach' || role === 'admin') resolvedRole = role;

      // Se a equipa já tem treinador, quem entra agora como 'coach' é
      // treinador-adjunto — mesmas permissões e painel do principal, só
      // muda o rótulo mostrado, e não abre um novo período no histórico
      // (esse continua a marcar só o treinador principal).
      if (resolvedRole === 'coach') {
        const existingCoach = await User.findOne({ where: { team_id: team.id, role: 'coach' } });
        if (existingCoach) isAssistantCoach = true;
      }
    } else if (team_name) {
      if (!String(team_name).trim()) throw new ApiError(400, 'O nome da equipa não pode ficar vazio');
      // Quem cria uma equipa fica sempre com um papel de liderança —
      // Treinador por omissão, ou Admin se explicitamente escolhido.
      newTeam = await Team.create({ name: String(team_name).trim() });
      resolvedTeamId = newTeam.id;
      resolvedRole = role === 'admin' ? 'admin' : 'coach';
    }

    const password_hash = await bcrypt.hash(password, 10);
    const user = await User.create({
      email,
      password_hash,
      name,
      role: resolvedRole,
      team_id: resolvedTeamId,
      ...(resolvedRole === 'coach' ? { coach_started_at: new Date() } : {}),
    });

    // Abre o primeiro registo do histórico de treinadores — só quando a
    // equipa é criada agora, com este utilizador como treinador. Quem
    // entra por código como 'coach' (treinador-adjunto, por exemplo)
    // numa equipa já existente não reabre nem duplica histórico; isso é
    // sempre feito de forma explícita pelo Admin, via
    // POST /admin/coach-history/transfer.
    if (newTeam && resolvedRole === 'coach') {
      await CoachHistory.create({ team_id: newTeam.id, user_id: user.id, started_at: new Date() });
    }

    // Regista a entrada na equipa — só quando entra mesmo por um caminho
    // real de adesão (código ou criação), não no registo de testes com
    // team_id direto.
    if (team_code || newTeam) {
      await MembershipHistory.create({ team_id: resolvedTeamId!, user_id: user.id, joined_at: new Date() });
    }

    const token = signToken(user);
    res.status(201).json({
      token,
      user: toProfile(user),
      is_assistant_coach: isAssistantCoach,
      ...(newTeam ? { team: { id: newTeam.id, name: newTeam.name, invite_code: newTeam.invite_code } } : {}),
    });
  } catch (err) {
    next(err);
  }
}

export async function login(req: Request, res: Response, next: NextFunction) {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      throw new ApiError(400, 'email e password são obrigatórios');
    }
    const user = await User.findOne({ where: { email } });
    if (!user) {
      throw new ApiError(401, 'Credenciais inválidas');
    }
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      throw new ApiError(401, 'Credenciais inválidas');
    }
    const token = signToken(user);
    res.status(200).json({ token, user: toProfile(user) });
  } catch (err) {
    next(err);
  }
}

/**
 * Pede um código de recuperação de password por email. Responde sempre
 * com sucesso, quer o email exista ou não na base de dados — isto evita
 * que alguém use este endpoint para descobrir que emails estão
 * registados na plataforma (enumeração de contas).
 */
export async function forgotPassword(req: Request, res: Response, next: NextFunction) {
  try {
    const { email } = req.body;
    if (!email) {
      throw new ApiError(400, 'email é obrigatório');
    }

    const user = await User.findOne({ where: { email } });
    if (user) {
      // Código numérico de 6 dígitos — mais fácil de escrever no
      // telemóvel do que um token longo, à semelhança de um SMS de
      // verificação.
      const code = crypto.randomInt(100000, 1000000).toString();
      const expires_at = new Date(Date.now() + RESET_CODE_TTL_MINUTES * 60 * 1000);

      await PasswordReset.create({
        user_id: user.id,
        code_hash: hashCode(code),
        expires_at,
      });

      await sendPasswordResetEmail(user.email, user.name, code);
    }

    res.status(200).json({
      message: 'Se o email existir na nossa plataforma, foi enviado um código de recuperação.',
    });
  } catch (err) {
    next(err);
  }
}

/**
 * Confirma o código de recuperação e define a nova password.
 */
export async function resetPassword(req: Request, res: Response, next: NextFunction) {
  try {
    const { email, code, new_password } = req.body;
    if (!email || !code || !new_password) {
      throw new ApiError(400, 'email, code e new_password são obrigatórios');
    }
    if (new_password.length < 8) {
      throw new ApiError(400, 'A nova password deve ter pelo menos 8 caracteres');
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      throw new ApiError(400, 'Código inválido ou expirado');
    }

    const reset = await PasswordReset.findOne({
      where: { user_id: user.id, code_hash: hashCode(String(code)), used: false },
      order: [['created_at', 'DESC']],
    });

    if (!reset || reset.expires_at.getTime() < Date.now()) {
      throw new ApiError(400, 'Código inválido ou expirado');
    }

    user.password_hash = await bcrypt.hash(new_password, 10);
    await user.save();

    reset.used = true;
    await reset.save();

    res.status(200).json({ message: 'Password atualizada com sucesso. Já podes iniciar sessão.' });
  } catch (err) {
    next(err);
  }
}
