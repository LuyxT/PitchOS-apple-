import { z } from 'zod';

export const createPlayerSchema = z.object({
  name: z.string().min(1, 'Player name is required').trim(),
  position: z.string().min(1, 'Player position is required').trim(),
  age: z.number().int().min(1, 'Age must be at least 1').max(99, 'Age must be at most 99'),
  teamId: z.string().uuid('Invalid team ID'),
});

export type CreatePlayerInput = z.infer<typeof createPlayerSchema>;
