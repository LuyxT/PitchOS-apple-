import { z } from 'zod';

export const createPlayerSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(1, 'Player name is required').trim(),
  number: z.number().int().min(0).default(0),
  position: z.string().min(1, 'Player position is required').trim(),
  status: z.string().default('available'),
  dateOfBirth: z.string().nullable().optional(),
  secondaryPositions: z.array(z.string()).default([]),
  heightCm: z.number().int().nullable().optional(),
  weightKg: z.number().int().nullable().optional(),
  preferredFoot: z.string().nullable().optional(),
  teamName: z.string().default(''),
  squadStatus: z.string().default('active'),
  joinedAt: z.string().nullable().optional(),
  roles: z.array(z.string()).default([]),
  groups: z.array(z.string()).default([]),
  injuryStatus: z.string().default('fit'),
  notes: z.string().default(''),
  developmentGoals: z.string().default(''),
  teamId: z.string().nullable().optional(),
});

export type CreatePlayerInput = z.infer<typeof createPlayerSchema>;
