import { Request, Response, NextFunction } from 'express';
import PDFDocument from 'pdfkit';
import bcrypt from 'bcryptjs';
import { User, Team, CoachHistory, Event, Attendance, Post, Achievement, Poll, GameStat, MembershipHistory, AuditLog } from '../models';
import { ApiError } from '../middleware/error';

// Regista uma ação administrativa para responsabilização institucional —
// nunca bloqueia nem falha o pedido principal se o registo falhar.
async function logAction(teamId: number, adminId: number, action: string, details?: string) {
  try {
    await AuditLog.create({ team_id: teamId, admin_id: adminId, action, details: details || null });
  } catch {
    // auditoria nunca deve impedir a ação em si
  }
}

// Devolve a equipa do próprio admin — todos os endpoints deste
// controlador trabalham sempre sobre req.user!.team_id, nunca sobre um
// id vindo do pedido, para não ser possível um admin de uma equipa
// consultar ou alterar dados de outra.
async function getOwnTeam(req: Request): Promise<Team> {
  const teamId = req.user!.team_id;
  if (!teamId) throw new ApiError(400, 'Não estás associado a nenhuma equipa');
  const team = await Team.findByPk(teamId);
  if (!team) throw new ApiError(404, 'Equipa não encontrada');
  return team;
}

// O "treinador atual" é sempre quem tem o registo aberto no histórico
// (ended_at null) — a fonte de verdade sobre quem é o principal. Com
// treinadores-adjuntos, pode haver mais do que um utilizador com
// role 'coach' na mesma equipa; só o principal aparece aqui.
async function getCurrentCoach(teamId: number): Promise<User | null> {
  const openRecord = await CoachHistory.findOne({
    where: { team_id: teamId, ended_at: null },
    order: [['started_at', 'DESC']],
  });
  if (openRecord) {
    const coach = await User.findByPk(openRecord.user_id);
    if (coach && coach.role === 'coach') return coach;
  }
  // Recurso — equipas sem histórico (ex: dados antigos/testes diretos).
  return User.findOne({ where: { team_id: teamId, role: 'coach' } });
}

function coachProfile(coach: User | null) {
  if (!coach) return null;
  return {
    id: coach.id,
    name: coach.name,
    email: coach.email,
    avatar_url: coach.avatar_url,
    coach_started_at: coach.coach_started_at,
    coach_phone: coach.coach_phone,
    coach_certification: coach.coach_certification,
    coach_notes: coach.coach_notes,
  };
}

// ---------------------------------------------------------------
// GET /admin/team — ficha institucional completa
// ---------------------------------------------------------------
export async function getTeamProfile(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const coach = await getCurrentCoach(team.id);
    const memberCount = await User.count({ where: { team_id: team.id, role: 'athlete' } });
    // Treinadores-adjuntos — qualquer 'coach' na equipa que não seja o
    // principal (o principal é quem getCurrentCoach devolveu).
    const allCoaches = await User.findAll({ where: { team_id: team.id, role: 'coach' }, order: [['name', 'ASC']] });
    const assistantCoaches = allCoaches.filter((c) => c.id !== coach?.id);

    res.status(200).json({
      id: team.id,
      name: team.name,
      description: team.description,
      invite_code: team.invite_code,
      founded_at: team.founded_at,
      age_group: team.age_group,
      modality: team.modality,
      home_venue: team.home_venue,
      season_started_at: team.season_started_at,
      created_at: team.created_at,
      member_count: memberCount,
      coach: coachProfile(coach),
      assistant_coaches: assistantCoaches.map((c) => coachProfile(c)),
    });
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// PATCH /admin/team — editar dados institucionais
// ---------------------------------------------------------------
export async function updateTeamProfile(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const { name, description, founded_at, age_group, modality, home_venue, season_started_at } = req.body;

    if (name !== undefined) {
      if (!String(name).trim()) throw new ApiError(400, 'O nome da equipa não pode ficar vazio');
      team.name = String(name).trim();
    }
    if (description !== undefined) team.description = description;
    if (founded_at !== undefined) team.founded_at = founded_at ? new Date(founded_at) : null;
    if (age_group !== undefined) team.age_group = age_group;
    if (modality !== undefined) team.modality = modality;
    if (home_venue !== undefined) team.home_venue = home_venue;
    if (season_started_at !== undefined) team.season_started_at = season_started_at ? new Date(season_started_at) : null;

    await team.save();
    await logAction(team.id, req.user!.id, 'update_team_profile', `Atualizou a ficha da equipa "${team.name}"`);
    res.status(200).json({ message: 'Dados da equipa atualizados com sucesso' });
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// PATCH /admin/coach — editar a ficha do treinador atual
// ---------------------------------------------------------------
export async function updateCoachProfile(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const { coach_id, coach_phone, coach_certification, coach_notes } = req.body;

    // Sem coach_id, edita o treinador principal (compatibilidade com o
    // comportamento anterior); com coach_id, permite editar também os
    // treinadores-adjuntos.
    let coach: User | null;
    if (coach_id) {
      coach = await User.findByPk(coach_id);
      if (!coach || coach.team_id !== team.id || coach.role !== 'coach') {
        throw new ApiError(404, 'Treinador não encontrado nesta equipa');
      }
    } else {
      coach = await getCurrentCoach(team.id);
    }
    if (!coach) throw new ApiError(404, 'A equipa não tem treinador atribuído no momento');

    if (coach_phone !== undefined) coach.coach_phone = coach_phone;
    if (coach_certification !== undefined) coach.coach_certification = coach_certification;
    if (coach_notes !== undefined) coach.coach_notes = coach_notes;

    await coach.save();
    await logAction(team.id, req.user!.id, 'update_coach_profile', `Atualizou a ficha do treinador ${coach.name}`);
    res.status(200).json({ message: 'Ficha do treinador atualizada com sucesso', coach: coachProfile(coach) });
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// GET /admin/coach-history — histórico completo de treinadores
// ---------------------------------------------------------------
export async function getCoachHistory(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const history = await CoachHistory.findAll({
      where: { team_id: team.id },
      include: [{ model: User, attributes: ['id', 'name', 'email', 'avatar_url'] }],
      order: [['started_at', 'DESC']],
    });
    res.status(200).json(
      history.map((h) => ({
        id: h.id,
        started_at: h.started_at,
        ended_at: h.ended_at,
        notes: h.notes,
        current: h.ended_at === null,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        user: (h as any).User,
      }))
    );
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// POST /admin/coach-history/transfer — trocar de treinador
// ---------------------------------------------------------------
export async function transferCoach(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const { name, email, password, notes } = req.body;
    if (!name || !String(name).trim()) throw new ApiError(400, 'O nome do novo treinador é obrigatório');
    if (!email || !String(email).trim()) throw new ApiError(400, 'O email do novo treinador é obrigatório');
    if (!password || String(password).length < 8) {
      throw new ApiError(400, 'A password do novo treinador tem de ter pelo menos 8 caracteres');
    }

    const existing = await User.findOne({ where: { email: String(email).trim() } });
    if (existing) throw new ApiError(409, 'Já existe uma conta com este email');

    const now = new Date();
    const currentCoach = await getCurrentCoach(team.id);

    if (currentCoach) {
      // Fecha o registo do treinador atual — nunca apaga histórico.
      const openRecord = await CoachHistory.findOne({
        where: { team_id: team.id, user_id: currentCoach.id, ended_at: null },
        order: [['started_at', 'DESC']],
      });
      if (openRecord) {
        openRecord.ended_at = now;
        await openRecord.save();
      }
      // Fecha também o registo de entrada/saída na equipa — o antigo
      // treinador sai da equipa por completo, não fica como atleta.
      const openMembership = await MembershipHistory.findOne({
        where: { team_id: team.id, user_id: currentCoach.id, left_at: null },
        order: [['joined_at', 'DESC']],
      });
      if (openMembership) {
        openMembership.left_at = now;
        openMembership.notes = notes || null;
        await openMembership.save();
      }
      currentCoach.role = 'athlete';
      currentCoach.team_id = null;
      currentCoach.coach_started_at = null;
      currentCoach.coach_phone = null;
      currentCoach.coach_certification = null;
      currentCoach.coach_notes = null;
      await currentCoach.save();
    }

    // Cria a conta do novo treinador — o Admin escolhe nome, email e
    // password, tal como um registo normal (a pessoa recebe depois as
    // credenciais para entrar).
    const password_hash = await bcrypt.hash(String(password), 10);
    const newCoach = await User.create({
      email: String(email).trim(),
      password_hash,
      name: String(name).trim(),
      role: 'coach',
      team_id: team.id,
      coach_started_at: now,
    });

    await CoachHistory.create({
      team_id: team.id,
      user_id: newCoach.id,
      started_at: now,
      notes: notes || null,
    });

    await MembershipHistory.create({ team_id: team.id, user_id: newCoach.id, joined_at: now });

    await logAction(
      team.id,
      req.user!.id,
      'transfer_coach',
      `Trocou o treinador: ${currentCoach ? currentCoach.name : 'ninguém'} → ${newCoach.name}${notes ? ` (${notes})` : ''}`
    );

    res.status(200).json({ message: 'Treinador trocado com sucesso', coach: coachProfile(newCoach) });
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// GET /admin/stats — métricas agregadas da equipa
// ---------------------------------------------------------------
export async function getAdminStats(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);

    const memberCount = await User.count({ where: { team_id: team.id, role: 'athlete' } });
    const events = await Event.findAll({ where: { team_id: team.id } });
    const eventIds = events.map((e) => e.id);
    const attendance = eventIds.length ? await Attendance.findAll({ where: { event_id: eventIds } }) : [];
    const present = attendance.filter((a) => a.status === 'present').length;
    const decided = attendance.filter((a) => a.status !== 'pending').length;
    const attendanceRate = decided === 0 ? 0 : Math.round((present / decided) * 100);

    const postCount = await Post.count({ where: { team_id: team.id } });
    const pollCount = await Poll.count({ where: { team_id: team.id } });

    const members = await User.findAll({ where: { team_id: team.id, role: 'athlete' } });
    const achievements = members.length
      ? await Achievement.findAll({ where: { user_id: members.map((m) => m.id) } })
      : [];
    const totalPoints = achievements.reduce((sum, a) => sum + a.points, 0);

    const now = new Date();
    const upcomingEvents = events.filter((e) => new Date(e.start_time) >= now).length;
    const pastEvents = events.length - upcomingEvents;

    res.status(200).json({
      member_count: memberCount,
      total_events: events.length,
      upcoming_events: upcomingEvents,
      past_events: pastEvents,
      attendance_rate: attendanceRate,
      post_count: postCount,
      poll_count: pollCount,
      total_points_awarded: totalPoints,
    });
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// GET /admin/roster — plantel completo, com estatísticas individuais
// minuciosas de cada atleta (presenças, pontos, estatísticas de jogo).
// ---------------------------------------------------------------
export async function getTeamRoster(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const members = await User.findAll({ where: { team_id: team.id, role: 'athlete' }, order: [['name', 'ASC']] });

    if (members.length === 0) {
      res.status(200).json([]);
      return;
    }

    const memberIds = members.map((m) => m.id);
    const attendance = await Attendance.findAll({ where: { user_id: memberIds } });
    const achievements = await Achievement.findAll({ where: { user_id: memberIds } });
    const gameStats = await GameStat.findAll({ where: { user_id: memberIds } });

    const roster = members.map((m) => {
      const own = attendance.filter((a) => a.user_id === m.id);
      const decided = own.filter((a) => a.status !== 'pending');
      const present = own.filter((a) => a.status === 'present');
      const attendanceRate = decided.length === 0 ? null : Math.round((present.length / decided.length) * 100);

      const ownAchievements = achievements.filter((a) => a.user_id === m.id);
      const points = ownAchievements.reduce((sum, a) => sum + a.points, 0);

      const ownStats = gameStats.filter((g) => g.user_id === m.id);
      const goals = ownStats.reduce((sum, g) => sum + g.goals, 0);
      const assists = ownStats.reduce((sum, g) => sum + g.assists, 0);
      const minutesPlayed = ownStats.reduce((sum, g) => sum + g.minutes_played, 0);

      return {
        id: m.id,
        name: m.name,
        email: m.email,
        avatar_url: m.avatar_url,
        position: m.position,
        jersey_number: m.jersey_number,
        attendance_rate: attendanceRate,
        present_count: present.length,
        total_decided: decided.length,
        points,
        achievements_count: ownAchievements.length,
        games_played: ownStats.length,
        goals,
        assists,
        minutes_played: minutesPlayed,
        emergency_contact_name: m.emergency_contact_name,
        emergency_contact_phone: m.emergency_contact_phone,
        guardian_name: m.guardian_name,
        guardian_phone: m.guardian_phone,
      };
    });

    res.status(200).json(roster);
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// DELETE /admin/roster/:userId — remover um atleta da equipa
// ---------------------------------------------------------------
export async function removeAthlete(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const userId = Number(req.params.userId);
    const member = await User.findByPk(userId);
    if (!member || member.team_id !== team.id) {
      throw new ApiError(404, 'Membro não encontrado nesta equipa');
    }
    if (member.role === 'admin') {
      throw new ApiError(400, 'Não é possível remover o Admin da equipa por aqui');
    }
    if (member.role === 'coach') {
      const principal = await getCurrentCoach(team.id);
      if (principal && principal.id === member.id) {
        throw new ApiError(400, 'Este é o treinador principal — usa a troca de treinador para o substituir');
      }
    }

    const now = new Date();
    const openRecord = await MembershipHistory.findOne({
      where: { team_id: team.id, user_id: member.id, left_at: null },
      order: [['joined_at', 'DESC']],
    });
    if (openRecord) {
      openRecord.left_at = now;
      openRecord.notes = (req.body?.reason as string) || null;
      await openRecord.save();
    }

    const memberName = member.name;
    const wasAssistantCoach = member.role === 'coach';
    // Sai da equipa — mantém a conta e o histórico associado (presenças,
    // conquistas, etc.), só deixa de estar associado a este plantel.
    member.team_id = null;
    if (wasAssistantCoach) {
      member.role = 'athlete';
      member.coach_started_at = null;
      member.coach_phone = null;
      member.coach_certification = null;
      member.coach_notes = null;
    }
    await member.save();

    await logAction(
      team.id,
      req.user!.id,
      'remove_athlete',
      `Removeu ${wasAssistantCoach ? 'o treinador-adjunto' : 'o atleta'} ${memberName} da equipa`
    );
    res.status(200).json({ message: `${memberName} foi removido(a) da equipa` });
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// GET /admin/membership-history — entradas e saídas de atletas
// ---------------------------------------------------------------
export async function getMembershipHistory(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const history = await MembershipHistory.findAll({
      where: { team_id: team.id },
      include: [{ model: User, attributes: ['id', 'name', 'email', 'avatar_url'] }],
      order: [['joined_at', 'DESC']],
    });
    res.status(200).json(
      history.map((h) => ({
        id: h.id,
        joined_at: h.joined_at,
        left_at: h.left_at,
        notes: h.notes,
        current: h.left_at === null,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        user: (h as any).User,
      }))
    );
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// GET /admin/season-comparison — estatísticas agrupadas por cada
// período de treinador (usa o histórico de treinadores como fronteira
// temporal entre "épocas", já que não há um modelo de época à parte).
// ---------------------------------------------------------------
export async function getSeasonComparison(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const history = await CoachHistory.findAll({
      where: { team_id: team.id },
      include: [{ model: User, attributes: ['name'] }],
      order: [['started_at', 'ASC']],
    });

    const allEvents = await Event.findAll({ where: { team_id: team.id } });
    const allEventIds = allEvents.map((e) => e.id);
    const allAttendance = allEventIds.length ? await Attendance.findAll({ where: { event_id: allEventIds } }) : [];
    // Pontos de quem já passou por esta equipa (atuais + antigos membros,
    // via histórico) — nunca de outra equipa.
    const everMemberIds = (
      await MembershipHistory.findAll({ where: { team_id: team.id }, attributes: ['user_id'] })
    ).map((m) => m.user_id);
    const currentMemberIds = (await User.findAll({ where: { team_id: team.id }, attributes: ['id'] })).map((u) => u.id);
    const relevantUserIds = Array.from(new Set([...everMemberIds, ...currentMemberIds]));
    const allAchievements = relevantUserIds.length ? await Achievement.findAll({ where: { user_id: relevantUserIds } }) : [];

    const periods = history.map((h) => {
      const start = new Date(h.started_at);
      const end = h.ended_at ? new Date(h.ended_at) : new Date();
      const periodEvents = allEvents.filter((e) => new Date(e.start_time) >= start && new Date(e.start_time) < end);
      const periodEventIds = periodEvents.map((e) => e.id);
      const periodAttendance = allAttendance.filter((a) => periodEventIds.includes(a.event_id));
      const decided = periodAttendance.filter((a) => a.status !== 'pending');
      const present = periodAttendance.filter((a) => a.status === 'present');
      const attendanceRate = decided.length === 0 ? null : Math.round((present.length / decided.length) * 100);
      const periodAchievements = allAchievements.filter(
        (a) => new Date(a.awarded_at) >= start && new Date(a.awarded_at) < end
      );
      const totalPoints = periodAchievements.reduce((s, a) => s + a.points, 0);

      return {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        coach_name: (h as any).User?.name || 'Utilizador removido',
        started_at: h.started_at,
        ended_at: h.ended_at,
        current: h.ended_at === null,
        events_total: periodEvents.length,
        trainings: periodEvents.filter((e) => e.type === 'training').length,
        matches: periodEvents.filter((e) => e.type === 'match').length,
        attendance_rate: attendanceRate,
        points_awarded: totalPoints,
      };
    });

    res.status(200).json(periods);
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// GET /admin/audit-log — registo de ações administrativas
// ---------------------------------------------------------------
export async function getAuditLog(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const logs = await AuditLog.findAll({
      where: { team_id: team.id },
      include: [{ model: User, attributes: ['id', 'name'] }],
      order: [['created_at', 'DESC']],
      limit: 200,
    });
    res.status(200).json(
      logs.map((l) => ({
        id: l.id,
        action: l.action,
        details: l.details,
        created_at: l.created_at,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        admin: (l as any).User,
      }))
    );
  } catch (err) {
    next(err);
  }
}

// ---------------------------------------------------------------
// GET /admin/coach/stats — estatísticas individuais e minuciosas do
// treinador atual: atividade de gestão, não desempenho de jogo.
// ---------------------------------------------------------------
export async function getCoachStats(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const coach = await getCurrentCoach(team.id);
    if (!coach) {
      res.status(200).json(null);
      return;
    }

    const eventsCreated = await Event.findAll({ where: { team_id: team.id, created_by: coach.id } });
    const trainingsCreated = eventsCreated.filter((e) => e.type === 'training').length;
    const matchesCreated = eventsCreated.filter((e) => e.type === 'match').length;

    const eventIds = eventsCreated.map((e) => e.id);
    const attendanceOnOwnEvents = eventIds.length ? await Attendance.findAll({ where: { event_id: eventIds } }) : [];
    const decidedOwn = attendanceOnOwnEvents.filter((a) => a.status !== 'pending');
    const presentOwn = attendanceOnOwnEvents.filter((a) => a.status === 'present');
    const attendanceRateOwnEvents = decidedOwn.length === 0 ? null : Math.round((presentOwn.length / decidedOwn.length) * 100);

    const postsPublished = await Post.count({ where: { team_id: team.id, author_id: coach.id } });
    const pollsCreated = await Poll.count({ where: { team_id: team.id, created_by: coach.id } });

    const tenureDays = coach.coach_started_at
      ? Math.max(0, Math.floor((Date.now() - new Date(coach.coach_started_at).getTime()) / 86400000))
      : null;

    res.status(200).json({
      coach_id: coach.id,
      tenure_days: tenureDays,
      events_created_total: eventsCreated.length,
      trainings_created: trainingsCreated,
      matches_created: matchesCreated,
      attendance_rate_own_events: attendanceRateOwnEvents,
      posts_published: postsPublished,
      polls_created: pollsCreated,
    });
  } catch (err) {
    next(err);
  }
}

// =================================================================
// Relatório PDF — motor de tabelas profissional (preto/branco, sem
// cor decorativa; hierarquia por peso tipográfico e regras finas).
// =================================================================
const PAGE_MARGIN = 50;
const INK = '#111111';
const RULE = '#B0B0B0';
const MUTED = '#5A5A5A';

function ensureSpace(doc: PDFKit.PDFDocument, needed: number) {
  const bottom = doc.page.height - doc.page.margins.bottom;
  if (doc.y + needed > bottom) {
    doc.addPage();
  }
}

function sectionHeader(doc: PDFKit.PDFDocument, title: string) {
  ensureSpace(doc, 50);
  doc.moveDown(0.6);
  const width = doc.page.width - PAGE_MARGIN * 2;
  doc
    .font('Helvetica-Bold')
    .fontSize(13)
    .fillColor(INK)
    .text(title.toUpperCase(), PAGE_MARGIN, doc.y, { width, characterSpacing: 0.5 });
  const y = doc.y + 2;
  doc
    .moveTo(PAGE_MARGIN, y)
    .lineTo(doc.page.width - PAGE_MARGIN, y)
    .lineWidth(1.2)
    .strokeColor(INK)
    .stroke();
  doc.x = PAGE_MARGIN;
  doc.y = y + 8;
}

// Tabela simples de pares label/valor — para fichas (equipa, treinador).
function keyValueTable(doc: PDFKit.PDFDocument, rows: Array<[string, string]>) {
  const labelW = 150;
  const rowH = 20;
  rows.forEach(([label, value]) => {
    ensureSpace(doc, rowH);
    const y = doc.y;
    doc.font('Helvetica-Bold').fontSize(9.5).fillColor(INK).text(label, PAGE_MARGIN, y, { width: labelW });
    doc
      .font('Helvetica')
      .fontSize(9.5)
      .fillColor(INK)
      .text(value, PAGE_MARGIN + labelW, y, { width: doc.page.width - PAGE_MARGIN * 2 - labelW });
    doc.y = Math.max(doc.y, y + rowH);
  });
  doc.x = PAGE_MARGIN;
}

interface TableColumn {
  header: string;
  width: number;
  align?: 'left' | 'right' | 'center';
}

// Tabela de dados a sério, com cabeçalho, linhas divisórias finas e
// quebra de página automática (repetindo o cabeçalho na página nova).
function fitText(doc: PDFKit.PDFDocument, text: string, maxWidth: number): string {
  if (doc.widthOfString(text) <= maxWidth) return text;
  let truncated = text;
  while (truncated.length > 1 && doc.widthOfString(truncated + '…') > maxWidth) {
    truncated = truncated.slice(0, -1);
  }
  return truncated + '…';
}

function dataTable(doc: PDFKit.PDFDocument, columns: TableColumn[], rows: string[][]) {
  const startX = PAGE_MARGIN;
  const rowH = 20;
  const headerH = 22;

  const drawHeader = () => {
    const y = doc.y;
    doc.font('Helvetica-Bold').fontSize(8.5).fillColor(INK);
    let x = startX;
    columns.forEach((col) => {
      doc.text(fitText(doc, col.header.toUpperCase(), col.width - 6), x + 3, y + 6, {
        width: col.width - 6,
        align: col.align || 'left',
        lineBreak: false,
      });
      x += col.width;
    });
    doc.y = y + headerH;
    doc
      .moveTo(startX, doc.y)
      .lineTo(startX + columns.reduce((s, c) => s + c.width, 0), doc.y)
      .lineWidth(1)
      .strokeColor(INK)
      .stroke();
    doc.x = PAGE_MARGIN;
  };

  ensureSpace(doc, headerH + rowH + 4);
  drawHeader();

  if (rows.length === 0) {
    ensureSpace(doc, rowH);
    doc.font('Helvetica-Oblique').fontSize(9).fillColor(MUTED).text('Sem registos.', startX + 3, doc.y + 5);
    doc.y += rowH;
    doc.x = PAGE_MARGIN;
    return;
  }

  rows.forEach((row, idx) => {
    if (doc.y + rowH > doc.page.height - doc.page.margins.bottom) {
      doc.addPage();
      doc.y = PAGE_MARGIN;
      drawHeader();
    }
    const y = doc.y;
    let x = startX;
    doc.font('Helvetica').fontSize(9).fillColor(INK);
    row.forEach((cell, i) => {
      const col = columns[i];
      doc.text(fitText(doc, cell, col.width - 6), x + 3, y + 5, {
        width: col.width - 6,
        align: col.align || 'left',
        lineBreak: false,
      });
      x += col.width;
    });
    doc.y = y + rowH;
    doc
      .moveTo(startX, doc.y)
      .lineTo(startX + columns.reduce((s, c) => s + c.width, 0), doc.y)
      .lineWidth(0.5)
      .strokeColor(RULE)
      .stroke();
    void idx;
  });
  doc.x = PAGE_MARGIN;
  doc.moveDown(0.4);
}

function fmtDatePt(d: Date | string | null): string {
  if (!d) return 'Não definida';
  return new Date(d).toLocaleDateString('pt-PT');
}

// ---------------------------------------------------------------
// GET /admin/report — relatório PDF completo da época
// ---------------------------------------------------------------
export async function getAdminReport(req: Request, res: Response, next: NextFunction) {
  try {
    const team = await getOwnTeam(req);
    const coach = await getCurrentCoach(team.id);
    const history = await CoachHistory.findAll({
      where: { team_id: team.id },
      include: [{ model: User, attributes: ['name'] }],
      order: [['started_at', 'ASC']],
    });

    const events = await Event.findAll({ where: { team_id: team.id }, order: [['start_time', 'ASC']] });
    const eventIds = events.map((e) => e.id);
    const attendance = eventIds.length ? await Attendance.findAll({ where: { event_id: eventIds } }) : [];
    const present = attendance.filter((a) => a.status === 'present').length;
    const decided = attendance.filter((a) => a.status !== 'pending').length;
    const attendanceRate = decided === 0 ? 0 : Math.round((present / decided) * 100);

    const members = await User.findAll({ where: { team_id: team.id, role: 'athlete' }, order: [['name', 'ASC']] });
    const memberIds = members.map((m) => m.id);
    const achievements = memberIds.length ? await Achievement.findAll({ where: { user_id: memberIds } }) : [];
    const gameStats = memberIds.length ? await GameStat.findAll({ where: { user_id: memberIds } }) : [];

    const pointsByUser = new Map<number, number>();
    for (const a of achievements) pointsByUser.set(a.user_id, (pointsByUser.get(a.user_id) || 0) + a.points);

    const attendanceByUser = new Map<number, { present: number; total: number }>();
    for (const a of attendance) {
      const entry = attendanceByUser.get(a.user_id) || { present: 0, total: 0 };
      if (a.status !== 'pending') entry.total += 1;
      if (a.status === 'present') entry.present += 1;
      attendanceByUser.set(a.user_id, entry);
    }

    const careerByUser = new Map<number, { goals: number; assists: number; minutes: number; games: number }>();
    for (const g of gameStats) {
      const entry = careerByUser.get(g.user_id) || { goals: 0, assists: 0, minutes: 0, games: 0 };
      entry.goals += g.goals;
      entry.assists += g.assists;
      entry.minutes += g.minutes_played;
      entry.games += 1;
      careerByUser.set(g.user_id, entry);
    }

    const postCount = await Post.count({ where: { team_id: team.id } });
    const pollCount = await Poll.count({ where: { team_id: team.id } });
    const trainingCount = events.filter((e) => e.type === 'training').length;
    const matchCount = events.filter((e) => e.type === 'match').length;

    // Atividade específica do treinador atual (não só totais da equipa).
    let coachStats: {
      eventsCreated: number;
      trainingsCreated: number;
      matchesCreated: number;
      postsPublished: number;
      pollsCreated: number;
      attendanceRateOwnEvents: number | null;
      tenureDays: number | null;
    } | null = null;
    if (coach) {
      const ownEvents = events.filter((e) => e.created_by === coach.id);
      const ownEventIds = ownEvents.map((e) => e.id);
      const ownAttendance = attendance.filter((a) => ownEventIds.includes(a.event_id));
      const ownDecided = ownAttendance.filter((a) => a.status !== 'pending');
      const ownPresent = ownAttendance.filter((a) => a.status === 'present');
      coachStats = {
        eventsCreated: ownEvents.length,
        trainingsCreated: ownEvents.filter((e) => e.type === 'training').length,
        matchesCreated: ownEvents.filter((e) => e.type === 'match').length,
        postsPublished: await Post.count({ where: { team_id: team.id, author_id: coach.id } }),
        pollsCreated: await Poll.count({ where: { team_id: team.id, created_by: coach.id } }),
        attendanceRateOwnEvents: ownDecided.length === 0 ? null : Math.round((ownPresent.length / ownDecided.length) * 100),
        tenureDays: coach.coach_started_at
          ? Math.max(0, Math.floor((Date.now() - new Date(coach.coach_started_at).getTime()) / 86400000))
          : null,
      };
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="relatorio-geral-${team.name.replace(/\s+/g, '-')}.pdf"`);

    const doc = new PDFDocument({ margin: PAGE_MARGIN, size: 'A4', bufferPages: true });
    doc.pipe(res);

    // ---- Cabeçalho / capa ----
    doc.font('Helvetica-Bold').fontSize(20).fillColor(INK).text('RELATÓRIO GERAL DA ÉPOCA', { characterSpacing: 0.5 });
    doc.font('Helvetica').fontSize(11).fillColor(MUTED).text('SportConnect — Documento institucional');
    doc.moveDown(0.5);
    doc.font('Helvetica-Bold').fontSize(15).fillColor(INK).text(team.name);
    doc
      .font('Helvetica')
      .fontSize(9)
      .fillColor(MUTED)
      .text(`Gerado em ${new Date().toLocaleDateString('pt-PT')} às ${new Date().toLocaleTimeString('pt-PT', { hour: '2-digit', minute: '2-digit' })}`);
    doc.moveDown(0.3);
    doc
      .moveTo(PAGE_MARGIN, doc.y)
      .lineTo(doc.page.width - PAGE_MARGIN, doc.y)
      .lineWidth(2)
      .strokeColor(INK)
      .stroke();

    // ---- Ficha da equipa ----
    sectionHeader(doc, 'Ficha da Equipa');
    keyValueTable(doc, [
      ['Escalão', team.age_group || 'Não definido'],
      ['Modalidade', team.modality || 'Não definida'],
      ['Local de treino', team.home_venue || 'Não definido'],
      ['Data de fundação', fmtDatePt(team.founded_at)],
      ['Código de convite', team.invite_code],
      ['Número de atletas', String(members.length)],
    ]);

    // ---- Treinador atual ----
    sectionHeader(doc, 'Treinador Atual');
    if (coach) {
      keyValueTable(doc, [
        ['Nome', coach.name],
        ['Email', coach.email],
        ['Contacto', coach.coach_phone || 'Não definido'],
        ['Certificação', coach.coach_certification || 'Não definida'],
        ['No cargo desde', fmtDatePt(coach.coach_started_at)],
        ['Notas', coach.coach_notes || '—'],
      ]);

      if (coachStats) {
        doc.moveDown(0.2);
        doc.font('Helvetica-Bold').fontSize(9.5).fillColor(INK).text('Atividade de gestão nesta equipa', PAGE_MARGIN, doc.y);
        doc.moveDown(0.2);
        keyValueTable(doc, [
          ['Dias no cargo', coachStats.tenureDays != null ? String(coachStats.tenureDays) : '—'],
          [
            'Eventos criados',
            `${coachStats.eventsCreated} (${coachStats.trainingsCreated} ${coachStats.trainingsCreated === 1 ? 'treino' : 'treinos'}, ${coachStats.matchesCreated} ${coachStats.matchesCreated === 1 ? 'jogo' : 'jogos'})`,
          ],
          [
            'Assiduidade nos seus eventos',
            coachStats.attendanceRateOwnEvents != null ? `${coachStats.attendanceRateOwnEvents}%` : '—',
          ],
          ['Avisos publicados', String(coachStats.postsPublished)],
          ['Sondagens criadas', String(coachStats.pollsCreated)],
        ]);
      }
    } else {
      doc.font('Helvetica-Oblique').fontSize(9.5).fillColor(MUTED).text('A equipa não tem treinador atribuído no momento.');
      doc.moveDown(0.5);
    }

    // ---- Histórico de treinadores ----
    sectionHeader(doc, 'Histórico de Treinadores');
    dataTable(
      doc,
      [
        { header: 'Nome', width: 220 },
        { header: 'Início', width: 130 },
        { header: 'Fim', width: 145 },
      ],
      history.map((h) => [
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (h as any).User?.name || 'Utilizador removido',
        fmtDatePt(h.started_at),
        h.ended_at ? fmtDatePt(h.ended_at) : 'Presente',
      ])
    );

    // ---- Atividade da época ----
    sectionHeader(doc, 'Atividade da Época');
    keyValueTable(doc, [
      ['Eventos totais', String(events.length)],
      ['Treinos', String(trainingCount)],
      ['Jogos', String(matchCount)],
      ['Taxa média de assiduidade', `${attendanceRate}%`],
      ['Avisos publicados', String(postCount)],
      ['Sondagens criadas', String(pollCount)],
    ]);

    // ---- Plantel — estatísticas individuais ----
    sectionHeader(doc, 'Plantel — Estatísticas Individuais');
    dataTable(
      doc,
      [
        { header: 'Nome', width: 122 },
        { header: 'Posição', width: 78 },
        { header: 'Nº', width: 26, align: 'center' },
        { header: 'Assid.', width: 48, align: 'center' },
        { header: 'Pontos', width: 42, align: 'center' },
        { header: 'Jogos', width: 38, align: 'center' },
        { header: 'Golos', width: 38, align: 'center' },
        { header: 'Assist.', width: 40, align: 'center' },
        { header: 'Minutos', width: 50, align: 'center' },
      ],
      members.map((m) => {
        const att = attendanceByUser.get(m.id);
        const rate = !att || att.total === 0 ? '—' : `${Math.round((att.present / att.total) * 100)}%`;
        const career = careerByUser.get(m.id) || { goals: 0, assists: 0, minutes: 0, games: 0 };
        return [
          m.name,
          m.position || '—',
          m.jersey_number != null ? String(m.jersey_number) : '—',
          rate,
          String(pointsByUser.get(m.id) || 0),
          String(career.games),
          String(career.goals),
          String(career.assists),
          String(career.minutes),
        ];
      })
    );

    // ---- Contactos de emergência ----
    sectionHeader(doc, 'Contactos de Emergência');
    doc
      .font('Helvetica-Oblique')
      .fontSize(8)
      .fillColor(MUTED)
      .text('Informação restrita — uso exclusivo em situação de emergência.');
    doc.moveDown(0.3);
    dataTable(
      doc,
      [
        { header: 'Atleta', width: 140 },
        { header: 'Contacto de Emergência', width: 190 },
        { header: 'Encarregado de Educação', width: 165 },
      ],
      members.map((m) => [
        m.name,
        [m.emergency_contact_name, m.emergency_contact_phone].filter(Boolean).join(' · ') || '—',
        [m.guardian_name, m.guardian_phone].filter(Boolean).join(' · ') || '—',
      ])
    );

    // ---- Rodapé com numeração ----
    // Escrever dentro da margem inferior faz o pdfkit paginar
    // automaticamente (interpreta como conteúdo a transbordar) — por
    // isso a margem é posta a zero só durante o desenho do rodapé.
    const pageRange = doc.bufferedPageRange();
    const originalBottomMargin = doc.page.margins.bottom;
    for (let i = 0; i < pageRange.count; i++) {
      doc.switchToPage(i);
      doc.page.margins.bottom = 0;
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor(MUTED)
        .text(`SportConnect — ${team.name} — Documento confidencial`, PAGE_MARGIN, doc.page.height - 35, {
          width: doc.page.width - PAGE_MARGIN * 2 - 60,
          lineBreak: false,
        });
      doc.text(`${i + 1} / ${pageRange.count}`, doc.page.width - PAGE_MARGIN - 60, doc.page.height - 35, {
        width: 60,
        align: 'right',
        lineBreak: false,
      });
      doc.page.margins.bottom = originalBottomMargin;
    }

    doc.end();
  } catch (err) {
    next(err);
  }
}
