import { z } from 'zod';

export const createTeamSchema = z.object({
  name: z.string().min(1, 'Team name is required').trim(),
  clubId: z.string().min(1, 'Club ID is required').optional(),
});

export type CreateTeamInput = z.infer<typeof createTeamSchema>;
