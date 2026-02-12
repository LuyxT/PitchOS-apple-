export type NextStep = 'CLUB_SETUP' | 'TEAM_SETUP' | 'DONE';

export interface OnboardingStatus {
  onboardingRequired: boolean;
  nextStep: NextStep;
}

export function resolveOnboardingStatus(user: {
  clubId?: string | null;
  teamId?: string | null;
}): OnboardingStatus {
  if (!user.clubId) {
    return {
      onboardingRequired: true,
      nextStep: 'CLUB_SETUP',
    };
  }

  if (!user.teamId) {
    return {
      onboardingRequired: true,
      nextStep: 'TEAM_SETUP',
    };
  }

  return {
    onboardingRequired: false,
    nextStep: 'DONE',
  };
}
