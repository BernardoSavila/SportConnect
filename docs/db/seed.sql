-- Dados de exemplo para desenvolvimento/demo
SET NAMES utf8mb4;
USE sportconnect;

INSERT INTO teams (name, description, invite_code, founded_at, age_group, modality, home_venue) VALUES
  ('Sporting CB', 'Equipa sénior de futsal', 'SPORT1', '2015-03-01', 'Sénior', 'Futsal', 'Pavilhão Municipal'),
  ('Juniores CB', 'Equipa de juniores', 'JUNIOR1', NULL, NULL, NULL, NULL);

-- password para todos: "Password123" (hash bcrypt gerado pelo seed.ts)
INSERT INTO users (email, password_hash, name, role, team_id, coach_started_at, coach_phone, coach_certification) VALUES
  ('admin@sportconnect.pt', '$2a$10$OqS.JkoVPcuPxZj.sDgQoeUvc/dKTU0SQG2eQCis9nch4PqdY8RjO', 'Carlos Mendes', 'admin', 1, NULL, NULL, NULL),
  ('coach@sportconnect.pt', '$2a$10$OqS.JkoVPcuPxZj.sDgQoeUvc/dKTU0SQG2eQCis9nch4PqdY8RjO', 'Treinador Silva', 'coach', 1, '2022-07-01', '912345678', 'Grau II UEFA'),
  ('atleta1@sportconnect.pt', '$2a$10$OqS.JkoVPcuPxZj.sDgQoeUvc/dKTU0SQG2eQCis9nch4PqdY8RjO', 'Bernardo Costa', 'athlete', 1, NULL, NULL, NULL),
  ('atleta2@sportconnect.pt', '$2a$10$OqS.JkoVPcuPxZj.sDgQoeUvc/dKTU0SQG2eQCis9nch4PqdY8RjO', 'Ana Ferreira', 'athlete', 1, NULL, NULL, NULL);

INSERT INTO coach_history (team_id, user_id, started_at) VALUES
  (1, 2, '2022-07-01');


INSERT INTO events (team_id, title, description, start_time, end_time, location, type, created_by) VALUES
  (1, 'Treino Táctico', 'Treino de finalização', '2026-08-01 18:00:00', '2026-08-01 19:30:00', 'Campo A', 'training', 1),
  (1, 'Jogo vs Rivais FC', 'Jornada 3', '2026-08-05 15:00:00', '2026-08-05 16:30:00', 'Estádio Municipal', 'match', 1);

INSERT INTO attendance (event_id, user_id, status) VALUES
  (1, 2, 'present'),
  (1, 3, 'pending'),
  (2, 2, 'pending'),
  (2, 3, 'pending');

INSERT INTO posts (team_id, author_id, content, media_url) VALUES
  (1, 1, 'Bem-vindos à nova época! Treinos às terças e quintas.', NULL),
  (1, 1, 'Parabéns pela vitória de sábado!', NULL);

INSERT INTO achievements (user_id, type, points) VALUES
  (2, 'MVP da Jornada', 50),
  (3, 'Assiduidade', 20);
