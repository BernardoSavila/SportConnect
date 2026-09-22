import { Request, Response, NextFunction } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';
import { ApiError } from '../middleware/error';

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    const name = crypto.randomBytes(16).toString('hex');
    cb(null, `${name}${ext}`);
  },
});

const ALLOWED_MIME = [
  // imagens
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  // áudio (mensagens de voz do chat)
  'audio/mp4',
  'audio/m4a',
  'audio/x-m4a',
  'audio/aac',
  'audio/mpeg',
  'audio/wav',
  'audio/webm',
  'audio/3gpp',
];

export const uploadMiddleware = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 }, // 8MB
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_MIME.includes(file.mimetype)) {
      cb(new ApiError(400, 'Tipo de ficheiro não suportado (imagens JPEG/PNG/WEBP/GIF ou áudio M4A/AAC/MP3/WAV)'));
      return;
    }
    cb(null, true);
  },
}).single('file');

export async function handleUpload(req: Request, res: Response, next: NextFunction) {
  try {
    if (!req.file) throw new ApiError(400, 'Nenhum ficheiro enviado (campo "file")');
    const publicUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    res.status(201).json({ url: publicUrl });
  } catch (err) {
    next(err);
  }
}
