import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

// ─── Default Category Seed Data ─────────────────────────────

const DEFAULT_CATEGORIES = [
  { name: 'Beiträge', colorHex: '#4CAF50', isDefault: true },
  { name: 'Material', colorHex: '#2196F3', isDefault: false },
  { name: 'Events', colorHex: '#FF9800', isDefault: false },
  { name: 'Getränke', colorHex: '#9C27B0', isDefault: false },
  { name: 'Transport', colorHex: '#795548', isDefault: false },
  { name: 'Sonstiges', colorHex: '#9E9E9E', isDefault: false },
];

// ─── Categories ─────────────────────────────────────────────

export async function ensureDefaultCategories(userId: string) {
  const prisma = getPrisma();

  const count = await prisma.cashCategory.count({ where: { userId } });
  if (count > 0) return;

  await prisma.cashCategory.createMany({
    data: DEFAULT_CATEGORIES.map((cat) => ({
      name: cat.name,
      colorHex: cat.colorHex,
      isDefault: cat.isDefault,
      userId,
    })),
  });
}

export async function listCategories(userId: string) {
  const prisma = getPrisma();

  const categories = await prisma.cashCategory.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
  });

  return categories.map(formatCategory);
}

// ─── Bootstrap ──────────────────────────────────────────────

export async function bootstrap(userId: string) {
  await ensureDefaultCategories(userId);

  const [categories, transactions, contributions, goals] = await Promise.all([
    listCategories(userId),
    listTransactionsForBootstrap(userId),
    listContributions(userId),
    listGoals(userId),
  ]);

  return { categories, transactions, contributions, goals };
}

async function listTransactionsForBootstrap(userId: string) {
  const prisma = getPrisma();

  const transactions = await prisma.cashTransaction.findMany({
    where: { userId },
    orderBy: { date: 'desc' },
    take: 50,
  });

  return transactions.map(formatTransaction);
}

// ─── Transactions ───────────────────────────────────────────

export interface ListTransactionsQuery {
  cursor?: string;
  limit?: number;
  from?: string;
  to?: string;
  categoryID?: string;
  playerID?: string;
  status?: string;
  type?: string;
  query?: string;
}

export async function listTransactions(userId: string, opts: ListTransactionsQuery) {
  const prisma = getPrisma();
  const take = Math.min(opts.limit ?? 50, 200);

  // Build the where clause
  const where: Record<string, unknown> = { userId };

  if (opts.categoryID) {
    where.categoryId = opts.categoryID;
  }
  if (opts.playerID) {
    where.playerID = opts.playerID;
  }
  if (opts.status) {
    where.paymentStatus = opts.status;
  }
  if (opts.type) {
    where.type = opts.type;
  }
  if (opts.from || opts.to) {
    const dateFilter: Record<string, Date> = {};
    if (opts.from) dateFilter.gte = new Date(opts.from);
    if (opts.to) dateFilter.lte = new Date(opts.to);
    where.date = dateFilter;
  }
  if (opts.query) {
    where.description = { contains: opts.query, mode: 'insensitive' };
  }

  const transactions = await prisma.cashTransaction.findMany({
    where,
    orderBy: { date: 'desc' },
    take: take + 1,
    ...(opts.cursor ? { skip: 1, cursor: { id: opts.cursor } } : {}),
  });

  const hasMore = transactions.length > take;
  const items = hasMore ? transactions.slice(0, take) : transactions;
  const nextCursor = hasMore ? items[items.length - 1].id : null;

  return {
    items: items.map(formatTransaction),
    nextCursor,
  };
}

export interface CreateTransactionInput {
  amount: number;
  date: string;
  categoryID: string;
  description: string;
  type: string;
  playerID?: string | null;
  responsibleTrainerID?: string | null;
  comment?: string;
  paymentStatus?: string;
  contextLabel?: string | null;
}

export async function createTransaction(userId: string, input: CreateTransactionInput) {
  const prisma = getPrisma();

  // Verify category belongs to user
  const category = await prisma.cashCategory.findFirst({
    where: { id: input.categoryID, userId },
  });
  if (!category) {
    throw new AppError(404, 'CATEGORY_NOT_FOUND', 'Cash category not found');
  }

  const transaction = await prisma.cashTransaction.create({
    data: {
      amount: input.amount,
      date: new Date(input.date),
      categoryId: input.categoryID,
      description: input.description,
      type: input.type,
      playerID: input.playerID ?? null,
      responsibleTrainerID: input.responsibleTrainerID ?? null,
      comment: input.comment ?? '',
      paymentStatus: input.paymentStatus ?? 'paid',
      contextLabel: input.contextLabel ?? null,
      userId,
    },
  });

  return formatTransaction(transaction);
}

export async function updateTransaction(userId: string, transactionId: string, input: Partial<CreateTransactionInput>) {
  const prisma = getPrisma();

  const existing = await prisma.cashTransaction.findFirst({
    where: { id: transactionId, userId },
  });
  if (!existing) {
    throw new AppError(404, 'TRANSACTION_NOT_FOUND', 'Transaction not found');
  }

  // If category is being changed, verify it belongs to user
  if (input.categoryID) {
    const category = await prisma.cashCategory.findFirst({
      where: { id: input.categoryID, userId },
    });
    if (!category) {
      throw new AppError(404, 'CATEGORY_NOT_FOUND', 'Cash category not found');
    }
  }

  const data: Record<string, unknown> = {};
  if (input.amount !== undefined) data.amount = input.amount;
  if (input.date !== undefined) data.date = new Date(input.date);
  if (input.categoryID !== undefined) data.categoryId = input.categoryID;
  if (input.description !== undefined) data.description = input.description;
  if (input.type !== undefined) data.type = input.type;
  if (input.playerID !== undefined) data.playerID = input.playerID;
  if (input.responsibleTrainerID !== undefined) data.responsibleTrainerID = input.responsibleTrainerID;
  if (input.comment !== undefined) data.comment = input.comment;
  if (input.paymentStatus !== undefined) data.paymentStatus = input.paymentStatus;
  if (input.contextLabel !== undefined) data.contextLabel = input.contextLabel;

  const updated = await prisma.cashTransaction.update({
    where: { id: transactionId },
    data,
  });

  return formatTransaction(updated);
}

export async function deleteTransaction(userId: string, transactionId: string) {
  const prisma = getPrisma();

  const existing = await prisma.cashTransaction.findFirst({
    where: { id: transactionId, userId },
  });
  if (!existing) {
    throw new AppError(404, 'TRANSACTION_NOT_FOUND', 'Transaction not found');
  }

  await prisma.cashTransaction.delete({ where: { id: transactionId } });
}

// ─── Contributions ──────────────────────────────────────────

export async function listContributions(userId: string) {
  const prisma = getPrisma();

  const contributions = await prisma.monthlyContribution.findMany({
    where: { userId },
    orderBy: { dueDate: 'desc' },
  });

  return contributions.map(formatContribution);
}

export interface CreateContributionInput {
  playerID: string;
  amount: number;
  dueDate: string;
  status?: string;
  monthKey: string;
}

export async function createContribution(userId: string, input: CreateContributionInput) {
  const prisma = getPrisma();

  const contribution = await prisma.monthlyContribution.create({
    data: {
      playerID: input.playerID,
      amount: input.amount,
      dueDate: new Date(input.dueDate),
      status: input.status ?? 'open',
      monthKey: input.monthKey,
      userId,
    },
  });

  return formatContribution(contribution);
}

export interface UpdateContributionInput {
  amount?: number;
  status?: string;
  dueDate?: string;
  monthKey?: string;
  lastReminderAt?: string | null;
}

export async function updateContribution(userId: string, contributionId: string, input: UpdateContributionInput) {
  const prisma = getPrisma();

  const existing = await prisma.monthlyContribution.findFirst({
    where: { id: contributionId, userId },
  });
  if (!existing) {
    throw new AppError(404, 'CONTRIBUTION_NOT_FOUND', 'Contribution not found');
  }

  const data: Record<string, unknown> = {};
  if (input.amount !== undefined) data.amount = input.amount;
  if (input.status !== undefined) data.status = input.status;
  if (input.dueDate !== undefined) data.dueDate = new Date(input.dueDate);
  if (input.monthKey !== undefined) data.monthKey = input.monthKey;
  if (input.lastReminderAt !== undefined) {
    data.lastReminderAt = input.lastReminderAt ? new Date(input.lastReminderAt) : null;
  }

  const updated = await prisma.monthlyContribution.update({
    where: { id: contributionId },
    data,
  });

  return formatContribution(updated);
}

export async function sendContributionReminders(userId: string, contributionIDs: string[]) {
  const prisma = getPrisma();

  const now = new Date();

  // Verify all contributions belong to the user
  const contributions = await prisma.monthlyContribution.findMany({
    where: { id: { in: contributionIDs }, userId },
  });

  if (contributions.length !== contributionIDs.length) {
    throw new AppError(404, 'CONTRIBUTION_NOT_FOUND', 'One or more contributions not found');
  }

  // Update lastReminderAt for all specified contributions
  await prisma.monthlyContribution.updateMany({
    where: { id: { in: contributionIDs }, userId },
    data: { lastReminderAt: now },
  });

  // Return updated contributions
  const updated = await prisma.monthlyContribution.findMany({
    where: { id: { in: contributionIDs } },
    orderBy: { dueDate: 'desc' },
  });

  return updated.map(formatContribution);
}

// ─── Goals ──────────────────────────────────────────────────

export async function listGoals(userId: string) {
  const prisma = getPrisma();

  const goals = await prisma.cashGoal.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });

  return goals.map(formatGoal);
}

export interface CreateGoalInput {
  name: string;
  targetAmount: number;
  currentProgress?: number;
  startDate: string;
  endDate: string;
}

export async function createGoal(userId: string, input: CreateGoalInput) {
  const prisma = getPrisma();

  const goal = await prisma.cashGoal.create({
    data: {
      name: input.name,
      targetAmount: input.targetAmount,
      currentProgress: input.currentProgress ?? 0,
      startDate: new Date(input.startDate),
      endDate: new Date(input.endDate),
      userId,
    },
  });

  return formatGoal(goal);
}

export interface UpdateGoalInput {
  name?: string;
  targetAmount?: number;
  currentProgress?: number;
  startDate?: string;
  endDate?: string;
}

export async function updateGoal(userId: string, goalId: string, input: UpdateGoalInput) {
  const prisma = getPrisma();

  const existing = await prisma.cashGoal.findFirst({
    where: { id: goalId, userId },
  });
  if (!existing) {
    throw new AppError(404, 'GOAL_NOT_FOUND', 'Goal not found');
  }

  const data: Record<string, unknown> = {};
  if (input.name !== undefined) data.name = input.name;
  if (input.targetAmount !== undefined) data.targetAmount = input.targetAmount;
  if (input.currentProgress !== undefined) data.currentProgress = input.currentProgress;
  if (input.startDate !== undefined) data.startDate = new Date(input.startDate);
  if (input.endDate !== undefined) data.endDate = new Date(input.endDate);

  const updated = await prisma.cashGoal.update({
    where: { id: goalId },
    data,
  });

  return formatGoal(updated);
}

export async function deleteGoal(userId: string, goalId: string) {
  const prisma = getPrisma();

  const existing = await prisma.cashGoal.findFirst({
    where: { id: goalId, userId },
  });
  if (!existing) {
    throw new AppError(404, 'GOAL_NOT_FOUND', 'Goal not found');
  }

  await prisma.cashGoal.delete({ where: { id: goalId } });
}

// ─── Formatters ─────────────────────────────────────────────

function formatCategory(cat: {
  id: string;
  name: string;
  colorHex: string;
  isDefault: boolean;
}) {
  return {
    id: cat.id,
    name: cat.name,
    colorHex: cat.colorHex,
    isDefault: cat.isDefault,
  };
}

function formatTransaction(tx: {
  id: string;
  amount: number;
  date: Date;
  categoryId: string;
  description: string;
  type: string;
  playerID: string | null;
  responsibleTrainerID: string | null;
  comment: string;
  paymentStatus: string;
  contextLabel: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: tx.id,
    amount: tx.amount,
    date: tx.date.toISOString(),
    categoryID: tx.categoryId,
    description: tx.description,
    type: tx.type,
    playerID: tx.playerID,
    responsibleTrainerID: tx.responsibleTrainerID,
    comment: tx.comment,
    paymentStatus: tx.paymentStatus,
    contextLabel: tx.contextLabel,
    createdAt: tx.createdAt.toISOString(),
    updatedAt: tx.updatedAt.toISOString(),
  };
}

function formatContribution(c: {
  id: string;
  playerID: string;
  amount: number;
  dueDate: Date;
  status: string;
  monthKey: string;
  lastReminderAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: c.id,
    playerID: c.playerID,
    amount: c.amount,
    dueDate: c.dueDate.toISOString(),
    status: c.status,
    monthKey: c.monthKey,
    lastReminderAt: c.lastReminderAt?.toISOString() ?? null,
    createdAt: c.createdAt.toISOString(),
    updatedAt: c.updatedAt.toISOString(),
  };
}

function formatGoal(g: {
  id: string;
  name: string;
  targetAmount: number;
  currentProgress: number;
  startDate: Date;
  endDate: Date;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: g.id,
    name: g.name,
    targetAmount: g.targetAmount,
    currentProgress: g.currentProgress,
    startDate: g.startDate.toISOString(),
    endDate: g.endDate.toISOString(),
    createdAt: g.createdAt.toISOString(),
    updatedAt: g.updatedAt.toISOString(),
  };
}
