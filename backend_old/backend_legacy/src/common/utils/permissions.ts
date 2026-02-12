import { RoleType } from '@prisma/client';

export enum Permission {
  CLUB_MANAGE = 'club:manage',
  TEAM_MANAGE = 'team:manage',
  ONBOARDING_MANAGE = 'onboarding:manage',
  ROSTER_READ = 'roster:read',
  ROSTER_WRITE = 'roster:write',
  CALENDAR_READ = 'calendar:read',
  CALENDAR_WRITE = 'calendar:write',
  TRAINING_READ = 'training:read',
  TRAINING_WRITE = 'training:write',
  TACTICS_READ = 'tactics:read',
  TACTICS_WRITE = 'tactics:write',
  ANALYSIS_READ = 'analysis:read',
  ANALYSIS_WRITE = 'analysis:write',
  MESSENGER_READ = 'messenger:read',
  MESSENGER_WRITE = 'messenger:write',
  FILES_READ = 'files:read',
  FILES_WRITE = 'files:write',
  FINANCE_READ = 'finance:read',
  FINANCE_WRITE = 'finance:write',
  PROFILE_READ = 'profile:read',
  PROFILE_WRITE = 'profile:write',
  SETTINGS_READ = 'settings:read',
  SETTINGS_WRITE = 'settings:write',
  WIDGETS_READ = 'widgets:read'
}

export const ROLE_PERMISSIONS: Record<RoleType, Permission[]> = {
  OWNER: Object.values(Permission),
  ADMIN: Object.values(Permission),
  COACH: [
    Permission.ONBOARDING_MANAGE,
    Permission.TEAM_MANAGE,
    Permission.ROSTER_READ,
    Permission.ROSTER_WRITE,
    Permission.CALENDAR_READ,
    Permission.CALENDAR_WRITE,
    Permission.TRAINING_READ,
    Permission.TRAINING_WRITE,
    Permission.TACTICS_READ,
    Permission.TACTICS_WRITE,
    Permission.ANALYSIS_READ,
    Permission.ANALYSIS_WRITE,
    Permission.MESSENGER_READ,
    Permission.MESSENGER_WRITE,
    Permission.FILES_READ,
    Permission.FILES_WRITE,
    Permission.FINANCE_READ,
    Permission.PROFILE_READ,
    Permission.PROFILE_WRITE,
    Permission.SETTINGS_READ,
    Permission.WIDGETS_READ
  ],
  ASSISTANT_COACH: [
    Permission.ROSTER_READ,
    Permission.CALENDAR_READ,
    Permission.CALENDAR_WRITE,
    Permission.TRAINING_READ,
    Permission.TRAINING_WRITE,
    Permission.TACTICS_READ,
    Permission.TACTICS_WRITE,
    Permission.ANALYSIS_READ,
    Permission.ANALYSIS_WRITE,
    Permission.MESSENGER_READ,
    Permission.MESSENGER_WRITE,
    Permission.FILES_READ,
    Permission.FILES_WRITE,
    Permission.PROFILE_READ,
    Permission.WIDGETS_READ
  ],
  PLAYER: [
    Permission.ROSTER_READ,
    Permission.CALENDAR_READ,
    Permission.TRAINING_READ,
    Permission.MESSENGER_READ,
    Permission.MESSENGER_WRITE,
    Permission.FILES_READ,
    Permission.PROFILE_READ,
    Permission.PROFILE_WRITE,
    Permission.WIDGETS_READ
  ],
  PHYSIO: [
    Permission.ROSTER_READ,
    Permission.TRAINING_READ,
    Permission.TRAINING_WRITE,
    Permission.MESSENGER_READ,
    Permission.MESSENGER_WRITE,
    Permission.FILES_READ,
    Permission.FILES_WRITE,
    Permission.PROFILE_READ,
    Permission.PROFILE_WRITE,
    Permission.WIDGETS_READ
  ],
  STAFF: [
    Permission.ROSTER_READ,
    Permission.CALENDAR_READ,
    Permission.MESSENGER_READ,
    Permission.MESSENGER_WRITE,
    Permission.FILES_READ,
    Permission.PROFILE_READ,
    Permission.WIDGETS_READ
  ],
  BOARD: [
    Permission.CLUB_MANAGE,
    Permission.TEAM_MANAGE,
    Permission.FINANCE_READ,
    Permission.FINANCE_WRITE,
    Permission.ROSTER_READ,
    Permission.CALENDAR_READ,
    Permission.MESSENGER_READ,
    Permission.FILES_READ,
    Permission.PROFILE_READ,
    Permission.SETTINGS_READ,
    Permission.SETTINGS_WRITE,
    Permission.WIDGETS_READ
  ]
};

export function hasPermission(roles: RoleType[], permission: Permission): boolean {
  return roles.some((role) => ROLE_PERMISSIONS[role]?.includes(permission));
}
