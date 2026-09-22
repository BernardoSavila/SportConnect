import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { ChatMessage, DirectMessage } from './models';

interface ChatAuthPayload {
  id: number;
  role: string;
  team_id: number | null;
}

function dmRoomName(idA: number, idB: number): string {
  const [a, b] = [idA, idB].sort((x, y) => x - y);
  return `dm:${a}-${b}`;
}

/// Configura o servidor Socket.io para chat em tempo real: chat de equipa
/// e mensagens privadas (1-para-1).
///
/// Protocolo de equipa (inalterado):
/// - `join` { teamId } / `message:send` { teamId, content?, mediaUrl?, type? }
/// - Servidor emite `message:new`.
///
/// Protocolo de mensagens privadas:
/// - `dm:join` { withUserId }         → entra na sala da conversa privada
/// - `dm:send` { toUserId, content?, mediaUrl?, type? } → envia mensagem
///   privada (persistida em BD).
/// - Servidor emite `dm:new` { id, sender_id, recipient_id, content, media_url, type, sent_at }
export function setupRealtime(httpServer: HttpServer) {
  const io = new SocketIOServer(httpServer, {
    cors: { origin: '*' },
  });

  io.use((socket: Socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) return next(new Error('Token em falta'));
    try {
      const secret = process.env.JWT_SECRET || 'dev-secret';
      const decoded = jwt.verify(token, secret) as ChatAuthPayload;
      socket.data.user = decoded;
      next();
    } catch {
      next(new Error('Token inválido'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const user: ChatAuthPayload = socket.data.user;

    socket.on('join', ({ teamId }: { teamId: number }) => {
      socket.join(`team:${teamId}`);
    });

    socket.on(
      'message:send',
      async ({
        teamId,
        content,
        mediaUrl,
        type,
      }: {
        teamId: number;
        content?: string;
        mediaUrl?: string;
        type?: 'text' | 'image' | 'audio';
      }) => {
        try {
          const messageType = type || 'text';
          if (messageType !== 'text' && !mediaUrl) {
            socket.emit('error', { message: 'mediaUrl é obrigatório para mensagens de imagem/áudio' });
            return;
          }
          if (messageType === 'text' && (!content || !content.trim())) return;

          const message = await ChatMessage.create({
            team_id: teamId,
            sender_id: user.id,
            content: content?.trim() || null,
            media_url: mediaUrl || null,
            type: messageType,
            sent_at: new Date(),
          });
          io.to(`team:${teamId}`).emit('message:new', {
            id: message.id,
            team_id: message.team_id,
            sender_id: message.sender_id,
            content: message.content,
            media_url: message.media_url,
            type: message.type,
            sent_at: message.sent_at,
          });
        } catch {
          socket.emit('error', { message: 'Não foi possível enviar a mensagem' });
        }
      }
    );

    socket.on('dm:join', ({ withUserId }: { withUserId: number }) => {
      socket.join(dmRoomName(user.id, withUserId));
    });

    socket.on(
      'dm:send',
      async ({
        toUserId,
        content,
        mediaUrl,
        type,
      }: {
        toUserId: number;
        content?: string;
        mediaUrl?: string;
        type?: 'text' | 'image' | 'audio';
      }) => {
        try {
          const messageType = type || 'text';
          if (messageType !== 'text' && !mediaUrl) {
            socket.emit('error', { message: 'mediaUrl é obrigatório para mensagens de imagem/áudio' });
            return;
          }
          if (messageType === 'text' && (!content || !content.trim())) return;

          const message = await DirectMessage.create({
            sender_id: user.id,
            recipient_id: toUserId,
            content: content?.trim() || null,
            media_url: mediaUrl || null,
            type: messageType,
            sent_at: new Date(),
          });
          io.to(dmRoomName(user.id, toUserId)).emit('dm:new', {
            id: message.id,
            sender_id: message.sender_id,
            recipient_id: message.recipient_id,
            content: message.content,
            media_url: message.media_url,
            type: message.type,
            sent_at: message.sent_at,
          });
        } catch {
          socket.emit('error', { message: 'Não foi possível enviar a mensagem privada' });
        }
      }
    );
  });

  return io;
}
