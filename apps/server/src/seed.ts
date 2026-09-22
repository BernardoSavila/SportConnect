import dotenv from 'dotenv';
dotenv.config();
import bcrypt from 'bcryptjs';
import { sequelize, Team, User, Event, Post, Achievement, CoachHistory } from './models';

async function seed() {
  await sequelize.sync({ force: true });

  const team = await Team.create({
    name: 'Sporting CB',
    description: 'Equipa sénior de futsal',
    invite_code: 'SPORT1',
    founded_at: new Date('2015-03-01'),
    age_group: 'Sénior',
    modality: 'Futsal',
    home_venue: 'Pavilhão Municipal',
  });

  const passwordHash = await bcrypt.hash('Password123', 10);

  const president = await User.create({
    email: 'admin@sportconnect.pt',
    password_hash: passwordHash,
    name: 'Carlos Mendes',
    role: 'admin',
    team_id: team.id,
  });

  const coachStartedAt = new Date('2022-07-01');
  const coach = await User.create({
    email: 'coach@sportconnect.pt',
    password_hash: passwordHash,
    name: 'Treinador Silva',
    role: 'coach',
    team_id: team.id,
    coach_started_at: coachStartedAt,
    coach_phone: '912345678',
    coach_certification: 'Grau II UEFA',
  });
  await CoachHistory.create({ team_id: team.id, user_id: coach.id, started_at: coachStartedAt });

  const athlete1 = await User.create({
    email: 'atleta1@sportconnect.pt',
    password_hash: passwordHash,
    name: 'Bernardo Costa',
    role: 'athlete',
    team_id: team.id,
  });

  const athlete2 = await User.create({
    email: 'atleta2@sportconnect.pt',
    password_hash: passwordHash,
    name: 'Ana Ferreira',
    role: 'athlete',
    team_id: team.id,
  });

  await Event.create({
    team_id: team.id,
    title: 'Treino Táctico',
    description: 'Treino de finalização',
    start_time: new Date('2026-08-01T18:00:00Z'),
    end_time: new Date('2026-08-01T19:30:00Z'),
    location: 'Campo A',
    type: 'training',
    created_by: coach.id,
  });

  await Post.create({
    team_id: team.id,
    author_id: coach.id,
    content: 'Bem-vindos à nova época! Treinos às terças e quintas.',
  });

  await Achievement.create({ user_id: athlete1.id, type: 'MVP da Jornada', points: 50 });
  await Achievement.create({ user_id: athlete2.id, type: 'Assiduidade', points: 20 });

  // eslint-disable-next-line no-console
  console.log('Seed concluído. Utilizadores de teste (password: Password123):');
  // eslint-disable-next-line no-console
  console.log(
    `  admin@sportconnect.pt (admin)\n  coach@sportconnect.pt (coach)\n  atleta1@sportconnect.pt (athlete)\n  atleta2@sportconnect.pt (athlete)`
  );
  await sequelize.close();
}

seed().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
