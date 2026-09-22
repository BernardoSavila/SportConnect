import dotenv from 'dotenv';
dotenv.config();

import http from 'http';
import { app } from './app';
import { sequelize } from './models';
import { setupRealtime } from './realtime';
import { startReminderJob } from './reminders';

const PORT = Number(process.env.PORT) || 3000;

async function start() {
  try {
    await sequelize.authenticate();
    // eslint-disable-next-line no-console
    console.log('Ligação à base de dados estabelecida.');
    await sequelize.sync(); // Em produção, usar migrations em vez de sync()

    const httpServer = http.createServer(app);
    setupRealtime(httpServer);

    httpServer.listen(PORT, () => {
      // eslint-disable-next-line no-console
      console.log(`SportConnect API a correr em http://localhost:${PORT}`);
      // eslint-disable-next-line no-console
      console.log('Chat em tempo real (Socket.io) ativo no mesmo endereço.');
      startReminderJob();
      // eslint-disable-next-line no-console
      console.log('Verificação automática de lembretes agendada (de hora a hora).');
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Não foi possível arrancar o servidor:', err);
    process.exit(1);
  }
}

start();
