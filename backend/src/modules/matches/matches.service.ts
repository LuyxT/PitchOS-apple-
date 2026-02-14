import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

/* ── DTO mapper ── */

function toMatchDTO(m: {
  id: string;
  opponent: string;
  date: Date;
  venue: string | null;
  result: string | null;
  teamId: string | null;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: m.id,
    opponent: m.opponent,
    date: m.date.toISOString(),
    venue: m.venue,
    result: m.result,
    teamId: m.teamId,
    userId: m.userId,
    createdAt: m.createdAt.toISOString(),
    updatedAt: m.updatedAt.toISOString(),
  };
}

/* ── Service functions ── */

export async function listMatches(userId: string) {
  const prisma = getPrisma();

  const matches = await prisma.match.findMany({
    where: { userId },
    orderBy: { date: 'desc' },
  });

  return matches.map(toMatchDTO);
}
