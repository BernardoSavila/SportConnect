import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import {
  getUserProfile,
  getRanking,
  updateAvatar,
  getAttendanceStats,
  updateEmergencyContact,
  updateProfile,
  changePassword,
} from '../controllers/userController';
import { getCareerStats } from '../controllers/gameStatController';

const usersRouter = Router();
usersRouter.get('/:id', authenticate, getUserProfile);
usersRouter.get('/:id/attendance-stats', authenticate, getAttendanceStats);
usersRouter.get('/:id/career-stats', authenticate, getCareerStats);
usersRouter.patch('/me/avatar', authenticate, updateAvatar);
usersRouter.patch('/me/contact', authenticate, updateEmergencyContact);
usersRouter.patch('/me/profile', authenticate, updateProfile);
usersRouter.patch('/me/password', authenticate, changePassword);

const rankingRouter = Router();
rankingRouter.get('/', authenticate, getRanking);

export { usersRouter, rankingRouter };
