import { Request, Response, NextFunction } from 'express';
import PDFDocument from 'pdfkit';
import { Op } from 'sequelize';
import { Event, Attendance, Post, Achievement, User, Team } from '../models';
import { ApiError } from '../middleware/error';

// Gera um PDF de resumo mensal da equipa: eventos, assiduidade média,
// top pontuadores e número de avisos publicados. Pensado para reuniões
// com pais/direção do clube.
export async function generateMonthlyReport(req: Request, res: Response, next: NextFunction) {
  try {
    const teamId = Number(req.query.teamId);
    const month = Number(req.query.month) || new Date().getMonth() + 1;
    const year = Number(req.query.year) || new Date().getFullYear();
    if (!teamId) throw new ApiError(400, 'teamId é obrigatório');

    const team = await Team.findByPk(teamId);
    if (!team) throw new ApiError(404, 'Equipa não encontrada');

    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 1);

    const events = await Event.findAll({
      where: { team_id: teamId, start_time: { [Op.gte]: start, [Op.lt]: end } },
      order: [['start_time', 'ASC']],
    });
    const eventIds = events.map((e) => e.id);
    const attendance = eventIds.length ? await Attendance.findAll({ where: { event_id: eventIds } }) : [];
    const present = attendance.filter((a) => a.status === 'present').length;
    const decided = attendance.filter((a) => a.status !== 'pending').length;
    const attendanceRate = decided === 0 ? 0 : Math.round((present / decided) * 100);

    const posts = await Post.count({
      where: { team_id: teamId, created_at: { [Op.gte]: start, [Op.lt]: end } },
    });

    const members = await User.findAll({ where: { team_id: teamId, role: 'athlete' } });
    const achievements = await Achievement.findAll({
      where: { user_id: members.map((m) => m.id), awarded_at: { [Op.gte]: start, [Op.lt]: end } },
    });
    const pointsByUser = new Map<number, number>();
    for (const a of achievements) pointsByUser.set(a.user_id, (pointsByUser.get(a.user_id) || 0) + a.points);
    const topScorers = members
      .map((m) => ({ name: m.name, points: pointsByUser.get(m.id) || 0 }))
      .sort((a, b) => b.points - a.points)
      .slice(0, 5);

    const monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="relatorio-${year}-${month}.pdf"`);

    const doc = new PDFDocument({ margin: 50 });
    doc.pipe(res);

    doc.fontSize(20).fillColor('#1856D6').text('SportConnect — Relatório Mensal', { align: 'left' });
    doc.moveDown(0.3);
    doc.fontSize(13).fillColor('#13233F').text(`${team.name} — ${monthNames[month - 1]} de ${year}`);
    doc.moveDown(1.2);

    doc.fontSize(14).fillColor('#1856D6').text('Resumo');
    doc.moveDown(0.3);
    doc.fontSize(11).fillColor('#13233F');
    doc.text(`Eventos realizados: ${events.length}`);
    doc.text(`Taxa média de assiduidade: ${attendanceRate}%`);
    doc.text(`Avisos publicados: ${posts}`);
    doc.moveDown(1);

    doc.fontSize(14).fillColor('#1856D6').text('Top 5 pontuadores do mês');
    doc.moveDown(0.3);
    doc.fontSize(11).fillColor('#13233F');
    if (topScorers.length === 0) {
      doc.text('Sem pontos atribuídos este mês.');
    } else {
      topScorers.forEach((s, i) => doc.text(`${i + 1}º ${s.name} — ${s.points} pts`));
    }
    doc.moveDown(1);

    doc.fontSize(14).fillColor('#1856D6').text('Eventos do mês');
    doc.moveDown(0.3);
    doc.fontSize(11).fillColor('#13233F');
    if (events.length === 0) {
      doc.text('Sem eventos agendados neste mês.');
    } else {
      events.forEach((e) => {
        const d = new Date(e.start_time);
        doc.text(`${d.toLocaleDateString('pt-PT')} — ${e.title} (${e.type === 'match' ? 'Jogo' : 'Treino'})`);
      });
    }

    doc.end();
  } catch (err) {
    next(err);
  }
}
