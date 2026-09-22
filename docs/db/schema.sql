-- SportConnect — Schema de base de dados (MySQL 8)
-- Corresponde ao ER descrito em docs/db/er.svg

-- Garante que o cliente lê/escreve este script como UTF-8 — sem isto, o
-- docker-entrypoint-initdb.d pode usar um charset de ligação diferente
-- (normalmente latin1) e corromper acentos/emojis logo na importação
-- (ex: "Parabéns" fica "ParabÃ©ns").
SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS sportconnect CHARACTER SET utf8mb4;
USE sportconnect;

CREATE TABLE teams (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  description TEXT,
  invite_code VARCHAR(8) UNIQUE NOT NULL,
  founded_at DATE NULL,
  age_group VARCHAR(40) NULL,
  modality VARCHAR(60) NULL,
  home_venue VARCHAR(120) NULL,
  season_started_at DATE NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(120) NOT NULL,
  role ENUM('athlete','coach','admin') DEFAULT 'athlete',
  team_id INT NULL,
  avatar_url VARCHAR(500) NULL,
  guardian_name VARCHAR(120) NULL,
  guardian_phone VARCHAR(30) NULL,
  emergency_contact_name VARCHAR(120) NULL,
  emergency_contact_phone VARCHAR(30) NULL,
  position VARCHAR(40) NULL,
  jersey_number INT NULL,
  coach_started_at DATE NULL,
  coach_phone VARCHAR(30) NULL,
  coach_certification VARCHAR(120) NULL,
  coach_notes TEXT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL
);

-- Regista quem treinou cada equipa, e quando — gerido pelo Admin
-- (role 'admin'). ended_at NULL = treinador em funções neste momento.
CREATE TABLE coach_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  user_id INT NOT NULL,
  started_at DATETIME NOT NULL,
  ended_at DATETIME NULL,
  notes TEXT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  start_time DATETIME NOT NULL,
  end_time DATETIME NOT NULL,
  location VARCHAR(200),
  type ENUM('training','match') NOT NULL,
  created_by INT NOT NULL,
  max_capacity INT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE TABLE attendance (
  id INT AUTO_INCREMENT PRIMARY KEY,
  event_id INT NOT NULL,
  user_id INT NOT NULL,
  status ENUM('pending','present','absent','waitlist') DEFAULT 'pending',
  confirmed_at DATETIME NULL,
  UNIQUE KEY uniq_event_user (event_id, user_id),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE posts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  author_id INT NOT NULL,
  content TEXT NOT NULL,
  media_url VARCHAR(500),
  is_official BOOLEAN NOT NULL DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users(id)
);

-- Gostos nos posts do feed
CREATE TABLE post_likes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  post_id INT NOT NULL,
  user_id INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_post_user (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE achievements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  type VARCHAR(100) NOT NULL,
  points INT DEFAULT 0,
  awarded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Stub para notificações push (Projeto 2 fará o envio real via FCM)
CREATE TABLE device_tokens (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token VARCHAR(500) NOT NULL,
  platform ENUM('android','ios') NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Chat da equipa — suporta texto, imagem e mensagens de voz.
CREATE TABLE chat_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  sender_id INT NOT NULL,
  content TEXT NULL,
  media_url VARCHAR(500) NULL,
  type ENUM('text','image','audio') DEFAULT 'text',
  sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id) REFERENCES users(id)
);

-- Sondagens/votações da equipa
CREATE TABLE polls (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  question VARCHAR(300) NOT NULL,
  created_by INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE TABLE poll_options (
  id INT AUTO_INCREMENT PRIMARY KEY,
  poll_id INT NOT NULL,
  text VARCHAR(200) NOT NULL,
  FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE
);

CREATE TABLE poll_votes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  poll_id INT NOT NULL,
  option_id INT NOT NULL,
  user_id INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_poll_user (poll_id, user_id),
  FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE,
  FOREIGN KEY (option_id) REFERENCES poll_options(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Estatísticas de desempenho por jogo/treino
CREATE TABLE game_stats (
  id INT AUTO_INCREMENT PRIMARY KEY,
  event_id INT NOT NULL,
  user_id INT NOT NULL,
  goals INT DEFAULT 0,
  assists INT DEFAULT 0,
  minutes_played INT DEFAULT 0,
  UNIQUE KEY uniq_event_user_stat (event_id, user_id),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Mensagens privadas (1-para-1)
CREATE TABLE direct_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  sender_id INT NOT NULL,
  recipient_id INT NOT NULL,
  content TEXT NULL,
  media_url VARCHAR(500) NULL,
  type ENUM('text','image','audio') DEFAULT 'text',
  sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Eventos guardados no calendário pessoal do atleta (dentro da app)
CREATE TABLE saved_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  event_id INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_user_event (user_id, event_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
);

-- Regista entradas e saídas de membros da equipa — mesmo espírito do
-- coach_history. left_at NULL = ainda está na equipa neste momento.
CREATE TABLE membership_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  user_id INT NOT NULL,
  joined_at DATETIME NOT NULL,
  left_at DATETIME NULL,
  notes TEXT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Regista ações administrativas do Admin, para responsabilização
-- institucional — nunca editado nem apagado depois de criado.
CREATE TABLE audit_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  admin_id INT NOT NULL,
  action VARCHAR(80) NOT NULL,
  details TEXT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Índices úteis
CREATE INDEX idx_events_team ON events(team_id, start_time);
CREATE INDEX idx_posts_team ON posts(team_id, created_at);
CREATE INDEX idx_achievements_user ON achievements(user_id);
