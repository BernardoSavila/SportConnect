import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { createTeam, getTeam, listMembers, getTeamByCode } from '../controllers/teamController';

const router = Router();
router.post('/', authenticate, createTeam);
router.get('/by-code/:code', getTeamByCode); // público — necessário durante o registo, antes de existir sessão
router.get('/:id', authenticate, getTeam);
router.get('/:id/members', authenticate, listMembers);

export default router;
