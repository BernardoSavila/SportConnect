import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import path from 'path';
import authRoutes from './routes/authRoutes';
import teamRoutes from './routes/teamRoutes';
import eventRoutes from './routes/eventRoutes';
import { feedRouter, postsRouter } from './routes/postRoutes';
import { usersRouter, rankingRouter } from './routes/userRoutes';
import deviceRoutes from './routes/deviceRoutes';
import chatRoutes from './routes/chatRoutes';
import mediaRoutes from './routes/mediaRoutes';
import achievementRoutes from './routes/achievementRoutes';
import pollRoutes from './routes/pollRoutes';
import reportRoutes from './routes/reportRoutes';
import directMessageRoutes from './routes/directMessageRoutes';
import reminderRoutes from './routes/reminderRoutes';
import adminRoutes from './routes/adminRoutes';
import { errorHandler, notFoundHandler } from './middleware/error';

export const app = express();

app.use(
  helmet({
    // permite que as imagens em /uploads sejam carregadas a partir da app mobile/outro host
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.status(200).json({ status: 'ok' }));

app.use('/auth', authRoutes);
app.use('/teams', teamRoutes);
app.use('/events', eventRoutes);
app.use('/feed', feedRouter);
app.use('/posts', postsRouter);
app.use('/users', usersRouter);
app.use('/ranking', rankingRouter);
app.use('/devices', deviceRoutes);
app.use('/chat', chatRoutes);
app.use('/media', mediaRoutes);
app.use('/achievements', achievementRoutes);
app.use('/polls', pollRoutes);
app.use('/reports', reportRoutes);
app.use('/messages/direct', directMessageRoutes);
app.use('/reminders', reminderRoutes);
app.use('/admin', adminRoutes);

// Ficheiros enviados (imagens de posts) — servidos como estáticos.
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.use(notFoundHandler);
app.use(errorHandler);
