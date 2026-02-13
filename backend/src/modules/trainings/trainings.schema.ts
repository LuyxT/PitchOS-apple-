import { z } from 'zod';

export const createTrainingSchema = z.object({
  title: z.string().min(1, 'Training title is required').trim(),
  description: z.string().optional(),
  date: z.string().datetime('Invalid date format'),
  teamId: z.string().uuid('Invalid team ID'),
});

export type CreateTrainingInput = z.infer<typeof createTrainingSchema>;
