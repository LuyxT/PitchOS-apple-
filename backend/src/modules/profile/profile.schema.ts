import { z } from 'zod';

export const saveProfileSchema = z.object({
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  phone: z.string().nullable().optional(),
  trainerLicenses: z.array(z.string()).nullable().optional(),
  trainerEducation: z.array(z.string()).nullable().optional(),
  trainerPhilosophy: z.string().nullable().optional(),
  trainerGoals: z.array(z.string()).nullable().optional(),
  trainerCareerHistory: z.string().nullable().optional(),
  physioQualifications: z.array(z.string()).nullable().optional(),
  boardFunction: z.string().nullable().optional(),
  boardResponsibilities: z.array(z.string()).nullable().optional(),
});

export type SaveProfileInput = z.infer<typeof saveProfileSchema>;
