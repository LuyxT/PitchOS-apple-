import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

/* ── DTO mapper ── */

function toFeedbackDTO(f: {
  id: string;
  player: string;
  summary: string;
  date: Date;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: f.id,
    player: f.player,
    summary: f.summary,
    date: f.date.toISOString(),
    userId: f.userId,
    createdAt: f.createdAt.toISOString(),
    updatedAt: f.updatedAt.toISOString(),
  };
}

/* ── Service functions ── */

export async function listFeedback(userId: string) {
  const prisma = getPrisma();

  const feedback = await prisma.feedback.findMany({
    where: { userId },
    orderBy: { date: 'desc' },
  });

  return feedback.map(toFeedbackDTO);
}
