import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as calendarService from './calendar.service';

// ─── Events ──────────────────────────────────────────────

export async function listEventsController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const events = await calendarService.listEvents(req.auth.userId);
  res.status(200).json(events);
}

export async function createEventController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const event = await calendarService.createEvent(req.body, req.auth.userId);
  res.status(201).json(event);
}

export async function updateEventController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const event = await calendarService.updateEvent(req.params.id, req.body, req.auth.userId);
  res.status(200).json(event);
}

export async function deleteEventController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  await calendarService.deleteEvent(req.params.id, req.auth.userId);
  res.status(200).json({ success: true });
}

// ─── Categories ──────────────────────────────────────────

export async function listCategoriesController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const categories = await calendarService.listCategories(req.auth.userId);
  res.status(200).json(categories);
}

export async function createCategoryController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const { name, colorHex } = req.body;
  if (!name || !colorHex) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Missing required fields: name, colorHex');
  }
  const category = await calendarService.createCategory(req.auth.userId, { name, colorHex });
  res.status(201).json(category);
}
