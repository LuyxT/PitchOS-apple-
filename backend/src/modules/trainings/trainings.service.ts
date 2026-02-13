import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';
import type { CreateTrainingInput } from './trainings.schema';

export async function createTraining(input: CreateTrainingInput) {
  const prisma = getPrisma();

  const team = await prisma.team.findUnique({ where: { id: input.teamId } });
  if (!team) {
    throw new AppError(404, 'TEAM_NOT_FOUND', 'Team not found');
  }

  return prisma.training.create({
    data: {
      title: input.title,
      description: input.description ?? null,
      date: new Date(input.date),
      teamId: input.teamId,
    },
  });
}

export async function listTrainings(teamId: string) {
  const prisma = getPrisma();
  return prisma.training.findMany({
    where: { teamId },
    orderBy: { date: 'desc' },
  });
}

export async function getTrainingById(trainingId: string) {
  const prisma = getPrisma();

  const training = await prisma.training.findUnique({ where: { id: trainingId } });
  if (!training) {
    throw new AppError(404, 'TRAINING_NOT_FOUND', 'Training not found');
  }

  return training;
}

export async function deleteTraining(trainingId: string) {
  const prisma = getPrisma();

  const existing = await prisma.training.findUnique({ where: { id: trainingId } });
  if (!existing) {
    throw new AppError(404, 'TRAINING_NOT_FOUND', 'Training not found');
  }

  await prisma.training.delete({ where: { id: trainingId } });
}
