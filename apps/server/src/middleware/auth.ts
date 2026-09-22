import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface AuthPayload {
  id: number;
  role: 'athlete' | 'coach' | 'admin';
  team_id: number | null;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthPayload;
    }
  }
}

export function authenticate(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  // A maioria das rotas usa o cabeçalho Authorization normal. Algumas
  // (como o .ics, aberto pela app de calendário externa) não conseguem
  // enviar cabeçalhos personalizados, por isso aceitam o token via query
  // string como alternativa.
  const token = header && header.startsWith('Bearer ')
    ? header.slice('Bearer '.length)
    : typeof req.query.token === 'string'
      ? req.query.token
      : null;

  if (!token) {
    return res.status(401).json({ error: 'Token em falta' });
  }
  try {
    const secret = process.env.JWT_SECRET || 'dev-secret';
    const decoded = jwt.verify(token, secret) as AuthPayload;
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ error: 'Token inválido ou expirado' });
  }
}

export function requireRole(...roles: Array<'athlete' | 'coach' | 'admin'>) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Sem permissão para esta ação' });
    }
    next();
  };
}
