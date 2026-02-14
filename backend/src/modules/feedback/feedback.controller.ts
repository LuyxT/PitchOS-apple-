import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as feedbackService from './feedback.service';

export async function listFeedback(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const feedback = await feedbackService.listFeedback(req.auth.userId);
  res.status(200).json(feedback);
}
