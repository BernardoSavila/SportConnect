import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import {
  getTeamProfile,
  updateTeamProfile,
  updateCoachProfile,
  getCoachHistory,
  transferCoach,
  getAdminStats,
  getTeamRoster,
  getCoachStats,
  removeAthlete,
  getMembershipHistory,
  getSeasonComparison,
  getAuditLog,
  getAdminReport,
} from '../controllers/adminController';

const router = Router();

// Todas as rotas deste módulo são exclusivas do Admin (role 'admin')
// da própria equipa — nunca trabalham sobre outra equipa.
router.get('/team', authenticate, requireRole('admin'), getTeamProfile);
router.patch('/team', authenticate, requireRole('admin'), updateTeamProfile);
router.patch('/coach', authenticate, requireRole('admin'), updateCoachProfile);
router.get('/coach/stats', authenticate, requireRole('admin'), getCoachStats);
router.get('/coach-history', authenticate, requireRole('admin'), getCoachHistory);
router.post('/coach-history/transfer', authenticate, requireRole('admin'), transferCoach);
router.get('/stats', authenticate, requireRole('admin'), getAdminStats);
router.get('/roster', authenticate, requireRole('admin'), getTeamRoster);
router.delete('/roster/:userId', authenticate, requireRole('admin'), removeAthlete);
router.get('/membership-history', authenticate, requireRole('admin'), getMembershipHistory);
router.get('/season-comparison', authenticate, requireRole('admin'), getSeasonComparison);
router.get('/audit-log', authenticate, requireRole('admin'), getAuditLog);
router.get('/report', authenticate, requireRole('admin'), getAdminReport);

export default router;
