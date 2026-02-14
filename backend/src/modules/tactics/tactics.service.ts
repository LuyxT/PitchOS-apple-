import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

/* ── DTO mapper ── */

function toTacticsStateDTO(s: {
  id: string;
  userId: string;
  activeScenarioID: string | null;
  scenarios: unknown;
  boards: unknown;
  updatedAt: Date;
}) {
  return {
    id: s.id,
    userId: s.userId,
    activeScenarioID: s.activeScenarioID,
    scenarios: s.scenarios,
    boards: s.boards,
    updatedAt: s.updatedAt.toISOString(),
  };
}

/* ── Service functions ── */

export async function getTacticsState(userId: string) {
  const prisma = getPrisma();

  let state = await prisma.tacticsState.findUnique({ where: { userId } });

  if (!state) {
    state = await prisma.tacticsState.create({
      data: {
        userId,
        activeScenarioID: null,
        scenarios: [],
        boards: [],
      },
    });
  }

  return toTacticsStateDTO(state);
}

export async function saveTacticsState(
  userId: string,
  input: { activeScenarioID?: string; scenarios?: unknown; boards?: unknown },
) {
  const prisma = getPrisma();

  const state = await prisma.tacticsState.upsert({
    where: { userId },
    create: {
      userId,
      activeScenarioID: input.activeScenarioID ?? null,
      scenarios: (input.scenarios ?? []) as any,
      boards: (input.boards ?? []) as any,
    },
    update: {
      activeScenarioID: input.activeScenarioID,
      scenarios: input.scenarios as any ?? undefined,
      boards: input.boards as any ?? undefined,
    },
  });

  return toTacticsStateDTO(state);
}
