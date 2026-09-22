import { Request, Response, NextFunction } from 'express';

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: any, req: Request, res: Response, next: NextFunction) {
  const status = err.status || 500;
  const message = err.message || 'Erro interno do servidor';
  if (status >= 500) {
    // eslint-disable-next-line no-console
    console.error(err);
  }
  res.status(status).json({ error: message });
}

export function notFoundHandler(req: Request, res: Response) {
  res.status(404).json({ error: `Rota não encontrada: ${req.method} ${req.originalUrl}` });
}
