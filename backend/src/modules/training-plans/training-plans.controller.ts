import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as svc from './training-plans.service';

// ─── Plans CRUD ─────────────────────────────────────────

export async function listPlansController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;
  const cursor = (req.query.cursor as string) || undefined;
  const from = (req.query.from as string) || undefined;
  const to = (req.query.to as string) || undefined;
  const coachId = (req.query.coachId as string) || undefined;

  const result = await svc.listPlans(req.auth.userId, { limit, cursor, from, to, coachId });
  res.status(200).json(result);
}

export async function getPlanController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const envelope = await svc.getPlanEnvelope(req.params.planId, req.auth.userId);
  res.status(200).json(envelope);
}

export async function createPlanController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  if (!req.body.title || !req.body.date) {
    throw new AppError(400, 'VALIDATION_ERROR', 'title and date are required');
  }
  const plan = await svc.createPlan(req.body, req.auth.userId);
  res.status(201).json(plan);
}

export async function updatePlanController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const plan = await svc.updatePlan(req.params.planId, req.body, req.auth.userId);
  res.status(200).json(plan);
}

export async function deletePlanController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  await svc.deletePlan(req.params.planId, req.auth.userId);
  res.status(200).json({ success: true });
}

// ─── Phases ─────────────────────────────────────────────

export async function savePhasesController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  if (!Array.isArray(req.body.phases)) {
    throw new AppError(400, 'VALIDATION_ERROR', 'phases array is required');
  }
  const phases = await svc.savePhases(req.params.planId, req.body.phases, req.auth.userId);
  res.status(200).json(phases);
}

// ─── Exercises ──────────────────────────────────────────

export async function saveExercisesController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  if (!Array.isArray(req.body.exercises)) {
    throw new AppError(400, 'VALIDATION_ERROR', 'exercises array is required');
  }
  const exercises = await svc.saveExercises(req.params.planId, req.body.exercises, req.auth.userId);
  res.status(200).json(exercises);
}

// ─── Exercise Templates ─────────────────────────────────

export async function createTemplateController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  if (!req.body.name) {
    throw new AppError(400, 'VALIDATION_ERROR', 'name is required');
  }
  const template = await svc.createTemplate(req.body, req.auth.userId);
  res.status(201).json(template);
}

export async function listTemplatesController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;
  const query = (req.query.query as string) || undefined;
  const cursor = (req.query.cursor as string) || undefined;

  const result = await svc.listTemplates(req.auth.userId, { query, cursor, limit });
  res.status(200).json(result);
}

// ─── Groups ─────────────────────────────────────────────

export async function createGroupController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  if (!req.body.name) {
    throw new AppError(400, 'VALIDATION_ERROR', 'name is required');
  }
  const group = await svc.createGroup(req.params.planId, req.body, req.auth.userId);
  res.status(201).json(group);
}

export async function updateGroupController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const group = await svc.updateGroup(req.params.groupId, req.body, req.auth.userId);
  res.status(200).json(group);
}

// ─── Briefings ──────────────────────────────────────────

export async function saveGroupBriefingController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const briefing = await svc.saveGroupBriefing(req.params.groupId, req.body, req.auth.userId);
  res.status(200).json(briefing);
}

// ─── Participants / Availability ────────────────────────

export async function saveParticipantsController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  if (!Array.isArray(req.body.participants)) {
    throw new AppError(400, 'VALIDATION_ERROR', 'participants array is required');
  }
  const availability = await svc.saveParticipants(req.params.planId, req.body.participants, req.auth.userId);
  res.status(200).json(availability);
}

// ─── Live Mode ──────────────────────────────────────────

export async function startLiveController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const plan = await svc.startLive(req.params.planId, req.body, req.auth.userId);
  res.status(200).json(plan);
}

export async function saveLiveStateController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const envelope = await svc.saveLiveState(req.params.planId, req.body, req.auth.userId);
  res.status(200).json(envelope);
}

export async function createDeviationController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  if (!req.body.kind) {
    throw new AppError(400, 'VALIDATION_ERROR', 'kind is required');
  }
  const deviation = await svc.createDeviation(req.params.planId, req.body, req.auth.userId);
  res.status(201).json(deviation);
}

// ─── Report ─────────────────────────────────────────────

export async function saveReportController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const report = await svc.saveReport(req.params.planId, req.body, req.auth.userId);
  res.status(200).json(report);
}

export async function getReportController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const report = await svc.getReport(req.params.planId, req.auth.userId);
  res.status(200).json(report);
}

// ─── Calendar Link ──────────────────────────────────────

export async function linkCalendarController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const event = await svc.linkCalendar(req.params.planId, req.body, req.auth.userId);
  res.status(201).json(event);
}

// ─── Duplicate ──────────────────────────────────────────

export async function duplicatePlanController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const plan = await svc.duplicatePlan(req.params.planId, req.body, req.auth.userId);
  res.status(201).json(plan);
}
