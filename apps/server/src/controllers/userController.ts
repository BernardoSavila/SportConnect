import { Request, Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import { User, Achievement, Attendance } from '../models';
import { ApiError } from '../middleware/error';

export async function getUserProfile(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) throw new ApiError(404, 'Utilizador não encontrado');
    const achievements = await Achievement.findAll({ where: { user_id: user.id } });
    const totalPoints = achievements.reduce((sum, a) => sum + a.points, 0);

    // Dados sensíveis (contactos de emergência/encarregado de educação) só
    // são devolvidos ao próprio utilizador ou a um treinador/admin da
    // mesma equipa — nunca a outros atletas.
    const requester = req.user!;
    const canSeeSensitive =
      requester.id === user.id || ((requester.role === 'coach' || requester.role === 'admin') && requester.team_id === user.team_id);

    res.status(200).json({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      team_id: user.team_id,
      avatar_url: user.avatar_url,
      position: user.position,
      jersey_number: user.jersey_number,
      achievements,
      total_points: totalPoints,
      ...(canSeeSensitive
        ? {
            guardian_name: user.guardian_name,
            guardian_phone: user.guardian_phone,
            emergency_contact_name: user.emergency_contact_name,
            emergency_contact_phone: user.emergency_contact_phone,
          }
        : {}),
    });
  } catch (err) {
    next(err);
  }
}

// Guarda os contactos de emergência/encarregado de educação do próprio
// utilizador autenticado (relevante sobretudo em desporto jovem).
export async function updateEmergencyContact(req: Request, res: Response, next: NextFunction) {
  try {
    const { guardian_name, guardian_phone, emergency_contact_name, emergency_contact_phone } = req.body;
    const user = await User.findByPk(req.user!.id);
    if (!user) throw new ApiError(404, 'Utilizador não encontrado');
    user.guardian_name = guardian_name ?? user.guardian_name;
    user.guardian_phone = guardian_phone ?? user.guardian_phone;
    user.emergency_contact_name = emergency_contact_name ?? user.emergency_contact_name;
    user.emergency_contact_phone = emergency_contact_phone ?? user.emergency_contact_phone;
    await user.save();
    res.status(200).json({
      guardian_name: user.guardian_name,
      guardian_phone: user.guardian_phone,
      emergency_contact_name: user.emergency_contact_name,
      emergency_contact_phone: user.emergency_contact_phone,
    });
  } catch (err) {
    next(err);
  }
}

// Atualiza os dados de "ficha de jogador" do próprio utilizador — nome,
// posição em campo e número de camisola. Todos opcionais.
export async function updateProfile(req: Request, res: Response, next: NextFunction) {
  try {
    const { name, position, jersey_number } = req.body;
    const user = await User.findByPk(req.user!.id);
    if (!user) throw new ApiError(404, 'Utilizador não encontrado');

    if (name !== undefined) {
      if (!String(name).trim()) throw new ApiError(400, 'O nome não pode ficar vazio');
      user.name = String(name).trim();
    }
    if (position !== undefined) user.position = position ? String(position).trim() : null;
    if (jersey_number !== undefined) {
      if (jersey_number !== null && (!Number.isInteger(jersey_number) || jersey_number < 0 || jersey_number > 999)) {
        throw new ApiError(400, 'jersey_number deve ser um número entre 0 e 999');
      }
      user.jersey_number = jersey_number;
    }
    await user.save();
    res.status(200).json({
      id: user.id,
      name: user.name,
      position: user.position,
      jersey_number: user.jersey_number,
    });
  } catch (err) {
    next(err);
  }
}

// Muda a password do próprio utilizador — exige a password atual correta.
export async function changePassword(req: Request, res: Response, next: NextFunction) {
  try {
    const { current_password, new_password } = req.body;
    if (!current_password || !new_password) {
      throw new ApiError(400, 'current_password e new_password são obrigatórios');
    }
    if (String(new_password).length < 8) {
      throw new ApiError(400, 'A nova password deve ter pelo menos 8 caracteres');
    }
    const user = await User.findByPk(req.user!.id);
    if (!user) throw new ApiError(404, 'Utilizador não encontrado');

    const valid = await bcrypt.compare(current_password, user.password_hash);
    if (!valid) throw new ApiError(401, 'Password atual incorreta');

    user.password_hash = await bcrypt.hash(new_password, 10);
    await user.save();
    res.status(200).json({ message: 'Password atualizada com sucesso' });
  } catch (err) {
    next(err);
  }
}

// Guarda o URL do avatar do próprio utilizador autenticado (a imagem em si
// é enviada previamente via POST /media/upload).
export async function updateAvatar(req: Request, res: Response, next: NextFunction) {
  try {
    const { avatar_url } = req.body;
    if (!avatar_url) throw new ApiError(400, 'avatar_url é obrigatório');
    const user = await User.findByPk(req.user!.id);
    if (!user) throw new ApiError(404, 'Utilizador não encontrado');
    user.avatar_url = avatar_url;
    await user.save();
    res.status(200).json({ id: user.id, avatar_url: user.avatar_url });
  } catch (err) {
    next(err);
  }
}

// Percentagem de assiduidade do atleta: presenças confirmadas sobre o
// total de eventos já decorridos (ignora eventos futuros/pendentes).
export async function getAttendanceStats(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = Number(req.params.id);
    const records = await Attendance.findAll({ where: { user_id: userId } });
    const present = records.filter((r) => r.status === 'present').length;
    const absent = records.filter((r) => r.status === 'absent').length;
    const pending = records.filter((r) => r.status === 'pending').length;
    const decided = present + absent;
    const percentage = decided === 0 ? 0 : Math.round((present / decided) * 100);
    res.status(200).json({ present, absent, pending, total: records.length, percentage });
  } catch (err) {
    next(err);
  }
}
export async function getRanking(req: Request, res: Response, next: NextFunction) {
  try {
    const teamId = Number(req.query.teamId);
    if (!teamId) throw new ApiError(400, 'teamId é obrigatório');

    const users = await User.findAll({ where: { team_id: teamId } });
    const results = await Promise.all(
      users.map(async (u) => {
        const total = (await Achievement.sum('points', { where: { user_id: u.id } })) || 0;
        return { user_id: u.id, name: u.name, total_points: total };
      })
    );
    results.sort((a, b) => b.total_points - a.total_points);
    res.status(200).json(results);
  } catch (err) {
    next(err);
  }
}
