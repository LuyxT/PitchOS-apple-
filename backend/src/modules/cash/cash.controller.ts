import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as cashService from './cash.service';

// ─── Bootstrap ──────────────────────────────────────────────

export async function bootstrapController(req: Request, res: Response) {
  const userId = req.auth!.userId;
  const data = await cashService.bootstrap(userId);
  res.status(200).json(data);
}

// ─── Transactions ───────────────────────────────────────────

export async function listTransactionsController(req: Request, res: Response) {
  const userId = req.auth!.userId;

  const opts: cashService.ListTransactionsQuery = {
    cursor: typeof req.query.cursor === 'string' ? req.query.cursor : undefined,
    limit: req.query.limit ? parseInt(req.query.limit as string, 10) : undefined,
    from: typeof req.query.from === 'string' ? req.query.from : undefined,
    to: typeof req.query.to === 'string' ? req.query.to : undefined,
    categoryID: typeof req.query.categoryID === 'string' ? req.query.categoryID : undefined,
    playerID: typeof req.query.playerID === 'string' ? req.query.playerID : undefined,
    status: typeof req.query.status === 'string' ? req.query.status : undefined,
    type: typeof req.query.type === 'string' ? req.query.type : undefined,
    query: typeof req.query.query === 'string' ? req.query.query : undefined,
  };

  const result = await cashService.listTransactions(userId, opts);
  res.status(200).json(result);
}

export async function createTransactionController(req: Request, res: Response) {
  const userId = req.auth!.userId;

  const { amount, date, categoryID, description, type, playerID, responsibleTrainerID, comment, paymentStatus, contextLabel } = req.body;

  if (amount === undefined || !date || !categoryID || !description || !type) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Missing required fields: amount, date, categoryID, description, type');
  }

  const transaction = await cashService.createTransaction(userId, {
    amount,
    date,
    categoryID,
    description,
    type,
    playerID: playerID ?? null,
    responsibleTrainerID: responsibleTrainerID ?? null,
    comment: comment ?? '',
    paymentStatus: paymentStatus ?? 'paid',
    contextLabel: contextLabel ?? null,
  });

  res.status(201).json(transaction);
}

export async function updateTransactionController(req: Request, res: Response) {
  const userId = req.auth!.userId;
  const { id } = req.params;

  const transaction = await cashService.updateTransaction(userId, id, req.body);
  res.status(200).json(transaction);
}

export async function deleteTransactionController(req: Request, res: Response) {
  const userId = req.auth!.userId;
  const { id } = req.params;

  await cashService.deleteTransaction(userId, id);
  res.status(200).json({ success: true });
}

// ─── Contributions ──────────────────────────────────────────

export async function createContributionController(req: Request, res: Response) {
  const userId = req.auth!.userId;

  const { playerID, amount, dueDate, status, monthKey } = req.body;

  if (!playerID || amount === undefined || !dueDate || !monthKey) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Missing required fields: playerID, amount, dueDate, monthKey');
  }

  const contribution = await cashService.createContribution(userId, {
    playerID,
    amount,
    dueDate,
    status,
    monthKey,
  });

  res.status(201).json(contribution);
}

export async function updateContributionController(req: Request, res: Response) {
  const userId = req.auth!.userId;
  const { id } = req.params;

  const contribution = await cashService.updateContribution(userId, id, req.body);
  res.status(200).json(contribution);
}

export async function sendContributionReminderController(req: Request, res: Response) {
  const userId = req.auth!.userId;

  const { contributionIDs } = req.body;

  if (!Array.isArray(contributionIDs) || contributionIDs.length === 0) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Missing required field: contributionIDs (non-empty array)');
  }

  const updated = await cashService.sendContributionReminders(userId, contributionIDs);
  res.status(200).json(updated);
}

// ─── Goals ──────────────────────────────────────────────────

export async function createGoalController(req: Request, res: Response) {
  const userId = req.auth!.userId;

  const { name, targetAmount, currentProgress, startDate, endDate } = req.body;

  if (!name || targetAmount === undefined || !startDate || !endDate) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Missing required fields: name, targetAmount, startDate, endDate');
  }

  const goal = await cashService.createGoal(userId, {
    name,
    targetAmount,
    currentProgress,
    startDate,
    endDate,
  });

  res.status(201).json(goal);
}

export async function updateGoalController(req: Request, res: Response) {
  const userId = req.auth!.userId;
  const { id } = req.params;

  const goal = await cashService.updateGoal(userId, id, req.body);
  res.status(200).json(goal);
}

export async function deleteGoalController(req: Request, res: Response) {
  const userId = req.auth!.userId;
  const { id } = req.params;

  await cashService.deleteGoal(userId, id);
  res.status(200).json({ success: true });
}
