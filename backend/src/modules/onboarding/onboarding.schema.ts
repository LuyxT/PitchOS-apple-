import { z } from 'zod';

export const onboardingClubSchema = z.object({
  name: z.string().min(1, 'Club name is required').trim(),
  region: z.string().min(1, 'Region is required').trim(),
  city: z.string().min(1, 'City is required').trim(),
});

export type OnboardingClubInput = z.infer<typeof onboardingClubSchema>;

export const onboardingTeamSchema = z.object({
  clubId: z.string().optional(),
  name: z.string().min(1, 'Team name is required').trim(),
  ageGroup: z.string().default('Senior'),
  league: z.string().default('Offen'),
});

export type OnboardingTeamInput = z.infer<typeof onboardingTeamSchema>;
