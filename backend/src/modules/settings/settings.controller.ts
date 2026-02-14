import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as settingsService from './settings.service';

// ─── Bootstrap ───────────────────────────────────────────

export async function getBootstrapController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await settingsService.getBootstrap(req.auth.userId);
  res.status(200).json(result);
}

// ─── Presentation ────────────────────────────────────────

export async function savePresentationController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await settingsService.savePresentation(req.auth.userId, req.body);
  res.status(200).json(result);
}

// ─── Notifications ───────────────────────────────────────

export async function saveNotificationsController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await settingsService.saveNotifications(req.auth.userId, req.body);
  res.status(200).json(result);
}

// ─── Security ────────────────────────────────────────────

export async function getSecurityController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await settingsService.getSecurity(req.auth.userId);
  res.status(200).json(result);
}

export async function changePasswordController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    throw new AppError(400, 'VALIDATION_ERROR', 'currentPassword and newPassword are required');
  }

  const result = await settingsService.changePassword(req.auth.userId, currentPassword, newPassword);
  res.status(200).json(result);
}

export async function updateTwoFactorController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const { enabled } = req.body;
  const result = await settingsService.updateTwoFactor(req.auth.userId, !!enabled);
  res.status(200).json(result);
}

export async function revokeSessionController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const { sessionID } = req.body;

  if (!sessionID) {
    throw new AppError(400, 'VALIDATION_ERROR', 'sessionID is required');
  }

  const result = await settingsService.revokeSession(req.auth.userId, sessionID);
  res.status(200).json(result);
}

export async function revokeAllSessionsController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  // Attempt to preserve the caller's current session by extracting
  // the token from the Authorization header. The current token's id
  // is not directly available from req.auth (access tokens don't carry
  // a tokenId), so we revoke all sessions for the user. If a
  // currentTokenId were available, it would be passed to exclude it.
  const result = await settingsService.revokeAllSessions(req.auth.userId);
  res.status(200).json(result);
}

// ─── App Info ────────────────────────────────────────────

export async function getAppInfoController(_req: Request, res: Response) {
  const result = settingsService.getAppInfo();
  res.status(200).json(result);
}

// ─── Feedback ────────────────────────────────────────────

export async function submitFeedbackController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const { message, category, rating } = req.body;

  if (!message) {
    throw new AppError(400, 'VALIDATION_ERROR', 'message is required');
  }

  const result = await settingsService.submitFeedback(
    req.auth.userId,
    message,
    category,
    rating
  );
  res.status(201).json(result);
}

// ─── Account ─────────────────────────────────────────────

export async function switchAccountContextController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const { teamID, role } = req.body;
  const result = await settingsService.switchAccountContext(
    req.auth.userId,
    teamID,
    role
  );
  res.status(200).json(result);
}

export async function deactivateAccountController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const result = await settingsService.deactivateAccount(req.auth.userId);
  res.status(200).json(result);
}

export async function leaveTeamController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const result = await settingsService.leaveTeam(req.auth.userId);
  res.status(200).json(result);
}
