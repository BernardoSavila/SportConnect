import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import {
  listEvents,
  getEvent,
  createEvent,
  updateEvent,
  deleteEvent,
  setAttendance,
  duplicateEvent,
} from '../controllers/eventController';
import { upsertGameStat, listGameStats } from '../controllers/gameStatController';
import { generateIcs } from '../controllers/icsController';
import { toggleSaveEvent, listSavedEvents } from '../controllers/savedEventController';

const router = Router();
router.get('/', authenticate, listEvents);
// IMPORTANTE: '/saved' tem de ficar antes de '/:id' — senão o Express
// interpretava "saved" como se fosse um :id de evento e nunca chegava aqui.
router.get('/saved', authenticate, listSavedEvents);
router.get('/:id', authenticate, getEvent);
router.get('/:id/ics', authenticate, generateIcs);
router.post('/', authenticate, requireRole('coach', 'admin'), createEvent);
router.patch('/:id', authenticate, requireRole('coach', 'admin'), updateEvent);
router.delete('/:id', authenticate, requireRole('coach', 'admin'), deleteEvent);
router.post('/:id/duplicate', authenticate, requireRole('coach', 'admin'), duplicateEvent);
router.post('/:id/attendance', authenticate, setAttendance);
router.post('/:id/save', authenticate, toggleSaveEvent);
router.get('/:id/stats', authenticate, listGameStats);
router.post('/:id/stats', authenticate, requireRole('coach', 'admin'), upsertGameStat);

export default router;
