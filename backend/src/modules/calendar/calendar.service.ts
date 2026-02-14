import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

const DEFAULT_CATEGORIES = [
  { name: 'Training', colorHex: '#4CAF50', isSystem: true },
  { name: 'Spiel', colorHex: '#2196F3', isSystem: true },
  { name: 'Meeting', colorHex: '#FF9800', isSystem: true },
  { name: 'Sonstiges', colorHex: '#9E9E9E', isSystem: true },
];

async function ensureDefaultCategories(userId: string) {
  const prisma = getPrisma();

  const count = await prisma.calendarCategory.count({ where: { userId } });
  if (count > 0) return;

  await prisma.calendarCategory.createMany({
    data: DEFAULT_CATEGORIES.map((cat) => ({ ...cat, userId })),
  });
}

// ─── Categories ──────────────────────────────────────────

export async function listCategories(userId: string) {
  const prisma = getPrisma();

  await ensureDefaultCategories(userId);

  const categories = await prisma.calendarCategory.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
  });

  return categories.map(formatCategoryResponse);
}

// ─── Events ──────────────────────────────────────────────

export interface CreateEventInput {
  title: string;
  startDate: string;
  endDate: string;
  categoryId?: string | null;
  visibility?: string;
  audience?: string;
  audiencePlayerIds?: string[];
  recurrence?: string | null;
  location?: string | null;
  notes?: string | null;
  linkedTrainingPlanID?: string | null;
  eventKind?: string;
  playerVisibleGoal?: string | null;
  playerVisibleDurationMinutes?: number | null;
}

export interface UpdateEventInput extends Partial<CreateEventInput> { }

export async function listEvents(userId: string) {
  const prisma = getPrisma();

  const events = await prisma.calendarEvent.findMany({
    where: { userId },
    include: { category: true },
    orderBy: { startDate: 'asc' },
  });

  return events.map(formatEventResponse);
}

export async function createEvent(input: CreateEventInput, userId: string) {
  const prisma = getPrisma();

  await ensureDefaultCategories(userId);

  // Validate categoryId exists if provided
  let categoryId = input.categoryId ?? null;
  if (categoryId) {
    const cat = await prisma.calendarCategory.findUnique({ where: { id: categoryId } });
    if (!cat) {
      categoryId = null;
    }
  }
  // Always assign a default category if none set
  if (!categoryId) {
    const fallback = await prisma.calendarCategory.findFirst({ where: { userId } });
    categoryId = fallback?.id ?? null;
  }

  const event = await prisma.calendarEvent.create({
    data: {
      title: input.title,
      startDate: new Date(input.startDate),
      endDate: new Date(input.endDate),
      categoryId,
      visibility: input.visibility ?? 'team',
      audience: input.audience ?? 'all',
      audiencePlayerIds: input.audiencePlayerIds ?? [],
      recurrence: input.recurrence ?? 'none',
      location: input.location ?? null,
      notes: input.notes ?? null,
      linkedTrainingPlanID: input.linkedTrainingPlanID ?? null,
      eventKind: input.eventKind ?? 'other',
      playerVisibleGoal: input.playerVisibleGoal ?? null,
      playerVisibleDurationMinutes: input.playerVisibleDurationMinutes ?? null,
      userId,
    },
    include: { category: true },
  });

  return formatEventResponse(event);
}

export async function updateEvent(eventId: string, input: UpdateEventInput, userId: string) {
  const prisma = getPrisma();

  const existing = await prisma.calendarEvent.findUnique({ where: { id: eventId } });
  if (!existing) {
    throw new AppError(404, 'EVENT_NOT_FOUND', 'Calendar event not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to update this event');
  }

  const data: Record<string, unknown> = {};
  if (input.title !== undefined) data.title = input.title;
  if (input.startDate !== undefined) data.startDate = new Date(input.startDate);
  if (input.endDate !== undefined) data.endDate = new Date(input.endDate);
  if (input.categoryId !== undefined) data.categoryId = input.categoryId;
  if (input.visibility !== undefined) data.visibility = input.visibility;
  if (input.audience !== undefined) data.audience = input.audience;
  if (input.audiencePlayerIds !== undefined) data.audiencePlayerIds = input.audiencePlayerIds;
  if (input.recurrence !== undefined) data.recurrence = input.recurrence;
  if (input.location !== undefined) data.location = input.location;
  if (input.notes !== undefined) data.notes = input.notes;
  if (input.linkedTrainingPlanID !== undefined) data.linkedTrainingPlanID = input.linkedTrainingPlanID;
  if (input.eventKind !== undefined) data.eventKind = input.eventKind;
  if (input.playerVisibleGoal !== undefined) data.playerVisibleGoal = input.playerVisibleGoal;
  if (input.playerVisibleDurationMinutes !== undefined) data.playerVisibleDurationMinutes = input.playerVisibleDurationMinutes;

  const event = await prisma.calendarEvent.update({
    where: { id: eventId },
    data,
    include: { category: true },
  });

  return formatEventResponse(event);
}

export async function deleteEvent(eventId: string, userId: string) {
  const prisma = getPrisma();

  const existing = await prisma.calendarEvent.findUnique({ where: { id: eventId } });
  if (!existing) {
    throw new AppError(404, 'EVENT_NOT_FOUND', 'Calendar event not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to delete this event');
  }

  await prisma.calendarEvent.delete({ where: { id: eventId } });
}

// ─── Response formatters ─────────────────────────────────

function formatCategoryResponse(category: {
  id: string;
  name: string;
  colorHex: string;
  isSystem: boolean;
}) {
  return {
    id: category.id,
    name: category.name,
    colorHex: category.colorHex,
    isSystem: category.isSystem,
  };
}

function formatEventResponse(event: {
  id: string;
  title: string;
  startDate: Date;
  endDate: Date;
  categoryId: string | null;
  visibility: string;
  audience: string;
  audiencePlayerIds: string[];
  recurrence: string | null;
  location: string | null;
  notes: string | null;
  linkedTrainingPlanID: string | null;
  eventKind: string;
  playerVisibleGoal: string | null;
  playerVisibleDurationMinutes: number | null;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
  category?: { id: string; name: string; colorHex: string; isSystem: boolean } | null;
}) {
  return {
    id: event.id,
    title: event.title,
    startDate: event.startDate.toISOString(),
    endDate: event.endDate.toISOString(),
    categoryId: event.categoryId ?? '',
    visibility: event.visibility,
    audience: event.audience,
    audiencePlayerIds: event.audiencePlayerIds,
    recurrence: event.recurrence ?? 'none',
    location: event.location,
    notes: event.notes,
    linkedTrainingPlanID: event.linkedTrainingPlanID,
    eventKind: event.eventKind,
    playerVisibleGoal: event.playerVisibleGoal,
    playerVisibleDurationMinutes: event.playerVisibleDurationMinutes,
    userId: event.userId,
    createdAt: event.createdAt.toISOString(),
    updatedAt: event.updatedAt.toISOString(),
    category: event.category ? formatCategoryResponse(event.category) : null,
  };
}
