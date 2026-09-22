import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

dotenv.config();

const isTest = process.env.NODE_ENV === 'test';

export const sequelize = isTest
  ? new Sequelize({
      dialect: 'sqlite',
      storage: ':memory:',
      logging: false,
    })
  : new Sequelize(
      process.env.DB_NAME || 'sportconnect',
      process.env.DB_USER || 'root',
      process.env.DB_PASSWORD || 'root',
      {
        host: process.env.DB_HOST || 'localhost',
        port: Number(process.env.DB_PORT) || 3306,
        dialect: 'mysql',
        logging: false,
        // Sem isto, a ligação negoceia um charset por omissão (normalmente
        // latin1), corrompendo acentos portugueses (ex.: "é" vira "Ã©").
        dialectOptions: {
          charset: 'utf8mb4',
        },
        define: {
          charset: 'utf8mb4',
          collate: 'utf8mb4_unicode_ci',
        },
      }
    );
