import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as adminService from './admin.service';

// ─── Tasks ──────────────────────────────────────────────

export async function listTasksController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const tasks = await adminService.listTasks(req.auth.userId);
  res.status(200).json(tasks);
}

// ─── Bootstrap ──────────────────────────────────────────

export async function getBootstrapController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const data = await adminService.getBootstrap(req.auth.userId);
  res.status(200).json(data);
}

// ─── Persons ────────────────────────────────────────────

export async function createPersonController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const person = await adminService.createPerson(req.body, req.auth.userId);
  res.status(201).json(person);
}

export async function updatePersonController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const person = await adminService.updatePerson(req.params.personId, req.body, req.auth.userId);
  res.status(200).json(person);
}

export async function deletePersonController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  await adminService.deletePerson(req.params.personId, req.auth.userId);
  res.status(200).json({ success: true });
}

// ─── Groups ─────────────────────────────────────────────

export async function createGroupController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const group = await adminService.createGroup(req.body, req.auth.userId);
  res.status(201).json(group);
}

export async function updateGroupController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const group = await adminService.updateGroup(req.params.groupId, req.body, req.auth.userId);
  res.status(200).json(group);
}

export async function deleteGroupController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  await adminService.deleteGroup(req.params.groupId, req.auth.userId);
  res.status(200).json({ success: true });
}

// ─── Invitations ────────────────────────────────────────

export async function createInvitationController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const invitation = await adminService.createInvitation(req.body, req.auth.userId);
  res.status(201).json(invitation);
}

export async function updateInvitationStatusController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const invitation = await adminService.updateInvitationStatus(
    req.params.invitationId,
    req.body.status,
    req.auth.userId,
  );
  res.status(200).json(invitation);
}

export async function resendInvitationController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const invitation = await adminService.resendInvitation(req.params.invitationId, req.auth.userId);
  res.status(200).json(invitation);
}

// ─── Audit ──────────────────────────────────────────────

export async function listAuditController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await adminService.listAuditEntries(
    {
      limit: req.query.limit ? Number(req.query.limit) : undefined,
      cursor: req.query.cursor as string | undefined,
      person: req.query.person as string | undefined,
      area: req.query.area as string | undefined,
      from: req.query.from as string | undefined,
      to: req.query.to as string | undefined,
    },
    req.auth.userId,
  );
  res.status(200).json(result);
}

// ─── Seasons ────────────────────────────────────────────

export async function createSeasonController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const season = await adminService.createSeason(req.body, req.auth.userId);
  res.status(201).json(season);
}

export async function updateSeasonController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const season = await adminService.updateSeason(req.params.seasonId, req.body, req.auth.userId);
  res.status(200).json(season);
}

export async function updateSeasonStatusController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const season = await adminService.updateSeasonStatus(
    req.params.seasonId,
    req.body.status,
    req.auth.userId,
  );
  res.status(200).json(season);
}

export async function activateSeasonController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await adminService.activateSeason(req.body.seasonID, req.auth.userId);
  res.status(200).json(result);
}

export async function duplicateRosterController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await adminService.duplicateRoster(
    req.params.seasonId,
    req.body.sourceSeasonID,
    req.auth.userId,
  );
  res.status(200).json(result);
}

// ─── Settings ───────────────────────────────────────────

export async function saveClubSettingsController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const settings = await adminService.saveClubSettings(req.body, req.auth.userId);
  res.status(200).json(settings);
}

export async function saveMessengerRulesController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const rules = await adminService.saveMessengerRules(req.body, req.auth.userId);
  res.status(200).json(rules);
}
