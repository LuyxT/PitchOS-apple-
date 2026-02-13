import { z } from 'zod';

export const createClubSchema = z.object({
  name: z.string().min(1, 'Club name is required').trim(),
  region: z.string().min(1, 'Club region is required').trim(),
});

export type CreateClubInput = z.infer<typeof createClubSchema>;
