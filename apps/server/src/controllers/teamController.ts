import { Request, Response, NextFunction } from 'express';
import { Team, User } from '../models';
import { ApiError } from '../middleware/error';

export async function createTeam(req: Request, res: Response, next: NextFunction) {
  try {
    const { name, description } = req.body;
    if (!name) throw new ApiError(400, 'name é obrigatório');
    const team = await Team.create({ name, description });
    res.status(201).json(team);
  } catch (err) {
    next(err);
  }
}

export async function getTeam(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await Team.findByPk(req.params.id);
    if (!team) throw new ApiError(404, 'Equipa não encontrada');
    res.status(200).json(team);
  } catch (err) {
    next(err);
  }
}

// Usado no registo — o utilizador introduz o código de convite da equipa
// em vez de escolher um team_id diretamente.
export async function getTeamByCode(req: Request, res: Response, next: NextFunction) {
  try {
    const code = String(req.params.code).toUpperCase();
    const team = await Team.findOne({ where: { invite_code: code } });
    if (!team) throw new ApiError(404, 'Código de equipa inválido');
    res.status(200).json({ id: team.id, name: team.name, invite_code: team.invite_code });
  } catch (err) {
    next(err);
  }
}

export async function listMembers(req: Request, res: Response, next: NextFunction) {
  try {
    const teamId = Number(req.params.id);
    const members = await User.findAll({
      where: { team_id: teamId },
      attributes: ['id', 'name', 'email', 'role', 'avatar_url'],
      order: [['name', 'ASC']],
    });
    res.status(200).json(members);
  } catch (err) {
    next(err);
  }
}
