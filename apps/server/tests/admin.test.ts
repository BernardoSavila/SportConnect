import request from 'supertest';
import { app } from '../src/app';
import { Team, User, CoachHistory, Event, Attendance, Achievement, GameStat, Post, MembershipHistory } from '../src/models';

async function registerAndLogin(email: string, role: 'athlete' | 'coach' | 'admin', team_id: number) {
  await request(app).post('/auth/register').send({ email, password: 'Password123', name: email, role, team_id });
  const res = await request(app).post('/auth/login').send({ email, password: 'Password123' });
  return res.body.token as string;
}

describe('Painel do Administrador (Admin)', () => {
  let teamId: number;
  let adminToken: string;
  let coachToken: string;
  let coachId: number;
  let athleteToken: string;
  let athleteId: number;
  let newCoachEmail: string;

  beforeAll(async () => {
    const team = await Team.create({ name: 'Sporting CB', description: 'x' });
    teamId = team.id;

    adminToken = await registerAndLogin('admin@sportconnect.pt', 'admin', teamId);
    coachToken = await registerAndLogin('treinador@sportconnect.pt', 'coach', teamId);
    athleteToken = await registerAndLogin('atleta-admin@sportconnect.pt', 'athlete', teamId);

    const coach = await User.findOne({ where: { email: 'treinador@sportconnect.pt' } });
    coachId = coach!.id;
    const athlete = await User.findOne({ where: { email: 'atleta-admin@sportconnect.pt' } });
    athleteId = athlete!.id;

    // regista o treinador no histórico manualmente (fora do fluxo de
    // registo direto por team_id, que não passa pelo authController)
    await CoachHistory.create({ team_id: teamId, user_id: coachId, started_at: new Date() });
    await MembershipHistory.create({ team_id: teamId, user_id: coachId, joined_at: new Date() });
  });

  // ---------------- Registo com escolha de papel ----------------
  describe('Registo — Admin vs Treinador ao criar equipa', () => {
    it('cria a equipa com o criador como treinador por omissão', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ email: 'coach-novo@sportconnect.pt', password: 'Password123', name: 'Novo', team_name: 'Equipa Nova A' });
      expect(res.status).toBe(201);
      expect(res.body.user.role).toBe('coach');
    });

    it('cria a equipa com o criador como presidente quando explicitamente escolhido', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({
          email: 'presidente-novo@sportconnect.pt',
          password: 'Password123',
          name: 'Novo Admin',
          role: 'admin',
          team_name: 'Equipa Nova B',
        });
      expect(res.status).toBe(201);
      expect(res.body.user.role).toBe('admin');
    });
  });

  // ---------------- Treinador adjunto ----------------
  describe('Treinador adjunto (entrar por código numa equipa que já tem treinador)', () => {
    it('não marca is_assistant_coach quando é o primeiro treinador da equipa', async () => {
      const teamRes = await request(app)
        .post('/auth/register')
        .send({ email: 'principal-a@sportconnect.pt', password: 'Password123', name: 'Principal A', team_name: 'Equipa Adjunto A' });
      expect(teamRes.body.is_assistant_coach).toBe(false);
    });

    it('marca is_assistant_coach quando já existe um treinador na equipa', async () => {
      const teamRow = await Team.create({ name: 'Equipa Adjunto B' });
      await registerAndLogin('principal-b@sportconnect.pt', 'coach', teamRow.id);
      // registerAndLogin usa team_id direto (caminho de testes), que não
      // passa pelo registo automático de histórico — cria-se à mão aqui,
      // tal como no beforeAll principal desta suite.
      const principalB = await User.findOne({ where: { email: 'principal-b@sportconnect.pt' } });
      await CoachHistory.create({ team_id: teamRow.id, user_id: principalB!.id, started_at: new Date() });

      const res = await request(app).post('/auth/register').send({
        email: 'adjunto-b@sportconnect.pt',
        password: 'Password123',
        name: 'Adjunto B',
        role: 'coach',
        team_code: teamRow.invite_code,
      });
      expect(res.status).toBe(201);
      expect(res.body.user.role).toBe('coach');
      expect(res.body.is_assistant_coach).toBe(true);

      // Mesmas permissões do treinador principal — consegue criar eventos.
      const eventRes = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${res.body.token}`)
        .send({
          team_id: teamRow.id,
          title: 'Treino do adjunto',
          start_time: '2026-09-08T18:00:00Z',
          end_time: '2026-09-08T19:00:00Z',
          type: 'training',
        });
      expect(eventRes.status).toBe(201);

      // Não abre um segundo período no histórico — só o principal conta.
      const adjuntoAdminToken = await registerAndLogin('admin-adjunto-b@sportconnect.pt', 'admin', teamRow.id);
      const history = await request(app).get('/admin/coach-history').set('Authorization', `Bearer ${adjuntoAdminToken}`);
      expect(history.body.length).toBe(1);

      // Aparece na ficha da equipa como treinador-adjunto, visível ao Admin.
      const teamProfile = await request(app).get('/admin/team').set('Authorization', `Bearer ${adjuntoAdminToken}`);
      expect(teamProfile.body.coach.name).toBe('principal-b@sportconnect.pt');
      expect(teamProfile.body.assistant_coaches.length).toBe(1);
      expect(teamProfile.body.assistant_coaches[0].name).toBe('Adjunto B');
    });
  });

  // ---------------- Autorização ----------------
  describe('Autorização', () => {
    it('impede um treinador de aceder aos endpoints de admin', async () => {
      const res = await request(app).get('/admin/team').set('Authorization', `Bearer ${coachToken}`);
      expect(res.status).toBe(403);
    });

    it('impede um atleta de aceder aos endpoints de admin', async () => {
      const res = await request(app).get('/admin/team').set('Authorization', `Bearer ${athleteToken}`);
      expect(res.status).toBe(403);
    });

    it('rejeita pedidos sem token', async () => {
      const res = await request(app).get('/admin/team');
      expect(res.status).toBe(401);
    });
  });

  // ---------------- Ficha da equipa ----------------
  describe('Ficha institucional da equipa', () => {
    it('devolve a ficha da equipa, incluindo o treinador atual', async () => {
      const res = await request(app).get('/admin/team').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(res.body.name).toBe('Sporting CB');
      expect(res.body.coach.email).toBe('treinador@sportconnect.pt');
      expect(res.body.member_count).toBe(1);
    });

    it('permite ao admin editar os dados institucionais', async () => {
      const res = await request(app)
        .patch('/admin/team')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ age_group: 'Sub-15', modality: 'Futebol 11', home_venue: 'Campo Municipal', founded_at: '2015-03-01' });
      expect(res.status).toBe(200);

      const check = await request(app).get('/admin/team').set('Authorization', `Bearer ${adminToken}`);
      expect(check.body.age_group).toBe('Sub-15');
      expect(check.body.modality).toBe('Futebol 11');
      expect(check.body.home_venue).toBe('Campo Municipal');
    });

    it('rejeita nome de equipa vazio', async () => {
      const res = await request(app).patch('/admin/team').set('Authorization', `Bearer ${adminToken}`).send({ name: '   ' });
      expect(res.status).toBe(400);
    });
  });

  // ---------------- Ficha do treinador ----------------
  describe('Ficha do treinador', () => {
    it('permite ao admin editar a ficha do treinador atual', async () => {
      const res = await request(app)
        .patch('/admin/coach')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ coach_phone: '912345678', coach_certification: 'Grau II UEFA', coach_notes: 'Excelente com os mais jovens.' });
      expect(res.status).toBe(200);
      expect(res.body.coach.coach_phone).toBe('912345678');
      expect(res.body.coach.coach_certification).toBe('Grau II UEFA');
    });
  });

  // ---------------- Histórico e troca de treinador ----------------
  describe('Histórico de treinadores', () => {
    it('mostra o treinador atual no histórico, sem data de fim', async () => {
      const res = await request(app).get('/admin/coach-history').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
      expect(res.body[0].current).toBe(true);
      expect(res.body[0].ended_at).toBeNull();
    });

    it('rejeita criar o novo treinador sem nome, email ou password', async () => {
      const res1 = await request(app)
        .post('/admin/coach-history/transfer')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ email: 'novo-treinador@sportconnect.pt', password: 'Password123' });
      expect(res1.status).toBe(400);

      const res2 = await request(app)
        .post('/admin/coach-history/transfer')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: 'Novo Treinador', password: 'Password123' });
      expect(res2.status).toBe(400);

      const res3 = await request(app)
        .post('/admin/coach-history/transfer')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: 'Novo Treinador', email: 'novo-treinador@sportconnect.pt', password: '123' });
      expect(res3.status).toBe(400);
    });

    it('rejeita criar o novo treinador com um email já registado', async () => {
      const res = await request(app)
        .post('/admin/coach-history/transfer')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: 'Duplicado', email: 'treinador@sportconnect.pt', password: 'Password123' });
      expect(res.status).toBe(409);
    });

    it('troca o treinador: cria a conta nova, fecha o registo antigo e abre um novo', async () => {
      const res = await request(app)
        .post('/admin/coach-history/transfer')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: 'Treinador Novo',
          email: 'treinador-novo@sportconnect.pt',
          password: 'Password123',
          notes: 'Contratação nova para a época',
        });
      expect(res.status).toBe(200);
      expect(res.body.coach.name).toBe('Treinador Novo');
      newCoachEmail = 'treinador-novo@sportconnect.pt';

      const newCoachUser = await User.findOne({ where: { email: 'treinador-novo@sportconnect.pt' } });
      expect(newCoachUser).not.toBeNull();
      expect(newCoachUser!.role).toBe('coach');
      expect(newCoachUser!.team_id).toBe(teamId);

      const history = await request(app).get('/admin/coach-history').set('Authorization', `Bearer ${adminToken}`);
      expect(history.body.length).toBe(2);
      const current = history.body.find((h: { current: boolean }) => h.current);
      const past = history.body.find((h: { current: boolean }) => !h.current);
      expect(current.user.id).toBe(newCoachUser!.id);
      expect(past.user.id).toBe(coachId);
      expect(past.ended_at).not.toBeNull();
    });

    it('o antigo treinador sai da equipa por completo (não fica como atleta dela)', async () => {
      const oldCoach = await User.findByPk(coachId);
      expect(oldCoach!.role).toBe('athlete');
      expect(oldCoach!.team_id).toBeNull();

      const history = await MembershipHistory.findOne({ where: { team_id: teamId, user_id: coachId } });
      expect(history!.left_at).not.toBeNull();
    });

    it('o novo treinador já consegue usar endpoints exclusivos de treinador', async () => {
      const loginRes = await request(app).post('/auth/login').send({ email: newCoachEmail, password: 'Password123' });
      const newCoachToken = loginRes.body.token;
      const res = await request(app)
        .post('/events')
        .set('Authorization', `Bearer ${newCoachToken}`)
        .send({ team_id: teamId, title: 'Treino', start_time: '2026-09-08T18:00:00Z', end_time: '2026-09-08T19:00:00Z', type: 'training' });
      expect(res.status).toBe(201);
    });
  });

  // ---------------- Estatísticas ----------------
  describe('Estatísticas agregadas', () => {
    it('devolve métricas coerentes da equipa', async () => {
      const res = await request(app).get('/admin/stats').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('member_count');
      expect(res.body).toHaveProperty('attendance_rate');
      expect(res.body).toHaveProperty('total_events');
    });
  });

  // ---------------- Estatísticas do treinador ----------------
  describe('Estatísticas individuais do treinador', () => {
    it('devolve a atividade de gestão do treinador atual', async () => {
      // Neste ponto da suite, o treinador atual é a conta nova criada no
      // teste de troca de treinador, acima (newCoachEmail).
      const newCoachUser = await User.findOne({ where: { email: newCoachEmail } });
      await Event.create({
        team_id: teamId,
        title: 'Treino criado pelo treinador',
        start_time: new Date('2026-09-02T18:00:00Z'),
        end_time: new Date('2026-09-02T19:00:00Z'),
        type: 'training',
        created_by: newCoachUser!.id,
      });

      const res = await request(app).get('/admin/coach/stats').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(res.body.coach_id).toBe(newCoachUser!.id);
      expect(res.body.events_created_total).toBeGreaterThanOrEqual(1);
      expect(res.body.trainings_created).toBeGreaterThanOrEqual(1);
      expect(res.body).toHaveProperty('tenure_days');
      expect(res.body).toHaveProperty('posts_published');
      expect(res.body).toHaveProperty('polls_created');
    });

    it('impede treinador e atleta de acederem às estatísticas do treinador', async () => {
      const resCoach = await request(app).get('/admin/coach/stats').set('Authorization', `Bearer ${coachToken}`);
      expect(resCoach.status).toBe(403);
      const resAthlete = await request(app).get('/admin/coach/stats').set('Authorization', `Bearer ${athleteToken}`);
      expect(resAthlete.status).toBe(403);
    });
  });

  // ---------------- Plantel detalhado ----------------
  describe('Plantel — estatísticas individuais', () => {
    it('devolve o plantel com estatísticas de presença, pontos e jogo', async () => {
      // Usa um atleta novo e dedicado, para não interferir com o
      // athleteId usado noutros testes da suite.
      await request(app)
        .post('/auth/register')
        .send({ email: 'plantel@sportconnect.pt', password: 'Password123', name: 'Atleta Plantel', role: 'athlete', team_id: teamId });
      const rosterAthlete = await User.findOne({ where: { email: 'plantel@sportconnect.pt' } });

      const event = await Event.create({
        team_id: teamId,
        title: 'Jogo de teste',
        start_time: new Date('2026-09-01T18:00:00Z'),
        end_time: new Date('2026-09-01T19:00:00Z'),
        type: 'match',
        created_by: coachId,
      });
      await Attendance.create({ event_id: event.id, user_id: rosterAthlete!.id, status: 'present' });
      await Achievement.create({ user_id: rosterAthlete!.id, type: 'MVP da Jornada', points: 50 });
      await GameStat.create({ event_id: event.id, user_id: rosterAthlete!.id, goals: 2, assists: 1, minutes_played: 40 });

      const res = await request(app).get('/admin/roster').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);

      const entry = res.body.find((r: { id: number }) => r.id === rosterAthlete!.id);
      expect(entry).toBeDefined();
      expect(entry.points).toBe(50);
      expect(entry.goals).toBe(2);
      expect(entry.assists).toBe(1);
      expect(entry.attendance_rate).toBe(100);
    });

    it('impede treinador e atleta de acederem ao plantel do admin', async () => {
      const resCoach = await request(app).get('/admin/roster').set('Authorization', `Bearer ${coachToken}`);
      expect(resCoach.status).toBe(403);
      const resAthlete = await request(app).get('/admin/roster').set('Authorization', `Bearer ${athleteToken}`);
      expect(resAthlete.status).toBe(403);
    });
  });

  // ---------------- Relatório PDF ----------------
  describe('Relatório geral em PDF', () => {
    it('gera um PDF válido', async () => {
      const res = await request(app).get('/admin/report').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toBe('application/pdf');
      expect(res.body.slice(0, 4).toString()).toBe('%PDF');
    });
  });

  // ---------------- Remover atleta e histórico de membros ----------------
  describe('Remover atleta e histórico de membros', () => {
    it('regista a entrada de quem se junta à equipa por código', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ email: 'novo-membro@sportconnect.pt', password: 'Password123', name: 'Novo Membro', team_code: 'INVALIDCODE' });
      expect(res.status).toBe(400); // código inválido de propósito, só a confirmar a validação

      const teamRow = await Team.findByPk(teamId);
      const res2 = await request(app)
        .post('/auth/register')
        .send({ email: 'novo-membro@sportconnect.pt', password: 'Password123', name: 'Novo Membro', team_code: teamRow!.invite_code });
      expect(res2.status).toBe(201);

      const novo = await User.findOne({ where: { email: 'novo-membro@sportconnect.pt' } });
      const history = await MembershipHistory.findOne({ where: { team_id: teamId, user_id: novo!.id } });
      expect(history).not.toBeNull();
      expect(history!.left_at).toBeNull();
    });

    it('remove um atleta da equipa e fecha o registo de entrada/saída', async () => {
      await request(app)
        .post('/auth/register')
        .send({ email: 'remover@sportconnect.pt', password: 'Password123', name: 'Atleta a Remover', role: 'athlete', team_id: teamId });
      const alvo = await User.findOne({ where: { email: 'remover@sportconnect.pt' } });
      await MembershipHistory.create({ team_id: teamId, user_id: alvo!.id, joined_at: new Date() });

      const res = await request(app)
        .delete(`/admin/roster/${alvo!.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Deixou o clube' });
      expect(res.status).toBe(200);

      const updated = await User.findByPk(alvo!.id);
      expect(updated!.team_id).toBeNull();

      const history = await request(app).get('/admin/membership-history').set('Authorization', `Bearer ${adminToken}`);
      const entry = history.body.find((h: { user: { id: number } }) => h.user.id === alvo!.id);
      expect(entry.current).toBe(false);
      expect(entry.left_at).not.toBeNull();
    });

    it('rejeita remover alguém que não é atleta desta equipa', async () => {
      const res = await request(app).delete('/admin/roster/999999').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(404);
    });

    it('impede treinador e atleta de removerem membros', async () => {
      const res = await request(app).delete(`/admin/roster/${athleteId}`).set('Authorization', `Bearer ${coachToken}`);
      expect(res.status).toBe(403);
    });
  });

  // ---------------- Gerir treinadores-adjuntos ----------------
  describe('Gerir treinadores-adjuntos', () => {
    it('permite ao admin remover um treinador-adjunto da equipa', async () => {
      await request(app).post('/auth/register').send({
        email: 'adjunto-remover@sportconnect.pt',
        password: 'Password123',
        name: 'Adjunto a Remover',
        role: 'coach',
        team_id: teamId,
      });
      const adjunto = await User.findOne({ where: { email: 'adjunto-remover@sportconnect.pt' } });
      await MembershipHistory.create({ team_id: teamId, user_id: adjunto!.id, joined_at: new Date() });

      const res = await request(app)
        .delete(`/admin/roster/${adjunto!.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Já não colabora com a equipa' });
      expect(res.status).toBe(200);

      const updated = await User.findByPk(adjunto!.id);
      expect(updated!.team_id).toBeNull();
      expect(updated!.role).toBe('athlete');
    });

    it('rejeita remover o treinador principal por esta via', async () => {
      const teamProfile = await request(app).get('/admin/team').set('Authorization', `Bearer ${adminToken}`);
      const principalId = teamProfile.body.coach.id;
      const res = await request(app).delete(`/admin/roster/${principalId}`).set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(400);
    });

    it('permite ao admin editar a ficha de um treinador-adjunto pelo id', async () => {
      await request(app).post('/auth/register').send({
        email: 'adjunto-editar@sportconnect.pt',
        password: 'Password123',
        name: 'Adjunto a Editar',
        role: 'coach',
        team_id: teamId,
      });
      const adjunto = await User.findOne({ where: { email: 'adjunto-editar@sportconnect.pt' } });

      const res = await request(app)
        .patch('/admin/coach')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ coach_id: adjunto!.id, coach_phone: '911222333' });
      expect(res.status).toBe(200);
      expect(res.body.coach.coach_phone).toBe('911222333');
    });
  });

  // ---------------- Comparação entre épocas ----------------
  describe('Comparação entre épocas (por período de treinador)', () => {
    it('devolve um período por cada treinador do histórico', async () => {
      const res = await request(app).get('/admin/season-comparison').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThanOrEqual(1);
      expect(res.body[0]).toHaveProperty('coach_name');
      expect(res.body[0]).toHaveProperty('events_total');
      expect(res.body[0]).toHaveProperty('attendance_rate');
    });
  });

  // ---------------- Época — início/fim ----------------
  describe('Definir início de época', () => {
    it('permite ao admin definir a data de início da época', async () => {
      const res = await request(app)
        .patch('/admin/team')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ season_started_at: '2026-09-01' });
      expect(res.status).toBe(200);

      const check = await request(app).get('/admin/team').set('Authorization', `Bearer ${adminToken}`);
      expect(check.body.season_started_at).toContain('2026-09-01');
    });
  });

  // ---------------- Avisos oficiais do Admin ----------------
  describe('Avisos oficiais do Admin', () => {
    it('marca automaticamente como oficial uma publicação feita pelo admin', async () => {
      const res = await request(app)
        .post('/posts')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ team_id: teamId, content: 'Comunicado oficial da direção' });
      expect(res.status).toBe(201);
      expect(res.body.is_official).toBe(true);
    });

    it('não marca como oficial uma publicação feita pelo treinador', async () => {
      const res = await request(app)
        .post('/posts')
        .set('Authorization', `Bearer ${coachToken}`)
        .send({ team_id: teamId, content: 'Aviso normal do treinador' });
      expect(res.status).toBe(201);
      expect(res.body.is_official).toBe(false);
    });

    it('o admin consegue editar e eliminar os seus próprios avisos', async () => {
      const created = await request(app)
        .post('/posts')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ team_id: teamId, content: 'Aviso a editar' });
      const postId = created.body.id;

      const edited = await request(app)
        .patch(`/posts/${postId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ content: 'Aviso editado' });
      expect(edited.status).toBe(200);
      expect(edited.body.content).toBe('Aviso editado');

      const deleted = await request(app).delete(`/posts/${postId}`).set('Authorization', `Bearer ${adminToken}`);
      expect(deleted.status).toBe(200);
    });

    it('o admin não consegue editar nem eliminar avisos de outra equipa', async () => {
      const otherTeam = await Team.create({ name: 'Outra Equipa Posts' });
      const otherAdminToken = await registerAndLogin('outro-admin-posts@sportconnect.pt', 'admin', otherTeam.id);
      const otherPost = await request(app)
        .post('/posts')
        .set('Authorization', `Bearer ${otherAdminToken}`)
        .send({ team_id: otherTeam.id, content: 'Aviso de outra equipa' });

      const editAttempt = await request(app)
        .patch(`/posts/${otherPost.body.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ content: 'Tentativa de editar' });
      expect(editAttempt.status).toBe(403);

      const deleteAttempt = await request(app).delete(`/posts/${otherPost.body.id}`).set('Authorization', `Bearer ${adminToken}`);
      expect(deleteAttempt.status).toBe(403);
    });
  });

  // ---------------- Registo de auditoria ----------------
  describe('Registo de auditoria', () => {
    it('regista as ações administrativas já realizadas nesta suite', async () => {
      const res = await request(app).get('/admin/audit-log').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThan(0);

      const actions = res.body.map((l: { action: string }) => l.action);
      expect(actions).toContain('update_team_profile');
      expect(actions).toContain('transfer_coach');
      expect(actions).toContain('remove_athlete');

      const entry = res.body[0];
      expect(entry.admin).toHaveProperty('name');
      expect(entry).toHaveProperty('created_at');
    });

    it('impede treinador e atleta de verem o registo de auditoria', async () => {
      const res = await request(app).get('/admin/audit-log').set('Authorization', `Bearer ${coachToken}`);
      expect(res.status).toBe(403);
    });
  });

  // ---------------- Isolamento entre equipas ----------------
  describe('Isolamento entre equipas', () => {
    it('o admin de uma equipa só vê a sua própria equipa', async () => {
      const otherTeam = await Team.create({ name: 'Outra Equipa Admin', description: 'x' });
      const otherAdminToken = await registerAndLogin('outro-admin@sportconnect.pt', 'admin', otherTeam.id);

      const res = await request(app).get('/admin/team').set('Authorization', `Bearer ${otherAdminToken}`);
      expect(res.status).toBe(200);
      expect(res.body.name).toBe('Outra Equipa Admin');
      expect(res.body.name).not.toBe('Sporting CB');
    });
  });
});
