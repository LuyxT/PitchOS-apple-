import { PrismaClient, PermissionType, RoleType } from '@prisma/client';
import { hash } from 'bcryptjs';

const prisma = new PrismaClient();

const rolePermissions: Record<RoleType, PermissionType[]> = {
  [RoleType.ADMIN]: [
    PermissionType.TRAINING_CREATE,
    PermissionType.TRAINING_EDIT,
    PermissionType.TRAINING_DELETE,
    PermissionType.SQUAD_EDIT,
    PermissionType.PEOPLE_MANAGE,
    PermissionType.MESSENGER_MANAGE,
    PermissionType.GROUPS_MANAGE,
    PermissionType.REPORT_RELEASE,
    PermissionType.SEASON_MANAGE,
    PermissionType.SETTINGS_EDIT,
    PermissionType.FILES_MANAGE,
    PermissionType.CASH_MANAGE,
  ],
  [RoleType.TRAINER]: [
    PermissionType.TRAINING_CREATE,
    PermissionType.TRAINING_EDIT,
    PermissionType.SQUAD_EDIT,
    PermissionType.GROUPS_MANAGE,
    PermissionType.REPORT_RELEASE,
    PermissionType.FILES_MANAGE,
  ],
  [RoleType.CO_TRAINER]: [
    PermissionType.TRAINING_EDIT,
    PermissionType.SQUAD_EDIT,
    PermissionType.REPORT_RELEASE,
  ],
  [RoleType.ANALYST]: [
    PermissionType.REPORT_RELEASE,
    PermissionType.FILES_MANAGE,
  ],
  [RoleType.TEAM_MANAGER]: [
    PermissionType.PEOPLE_MANAGE,
    PermissionType.GROUPS_MANAGE,
    PermissionType.MESSENGER_MANAGE,
    PermissionType.CASH_MANAGE,
  ],
  [RoleType.PHYSIO]: [
    PermissionType.REPORT_RELEASE,
  ],
  [RoleType.PLAYER]: [],
  [RoleType.BOARD]: [
    PermissionType.SEASON_MANAGE,
    PermissionType.SETTINGS_EDIT,
    PermissionType.PEOPLE_MANAGE,
  ],
};

async function main() {
  const organization = await prisma.organization.upsert({
    where: { id: '00000000-0000-0000-0000-000000000001' },
    update: { name: 'PitchInsights Verein' },
    create: {
      id: '00000000-0000-0000-0000-000000000001',
      name: 'PitchInsights Verein',
    },
  });

  const firstTeam = await prisma.team.upsert({
    where: { id: '00000000-0000-0000-0000-000000000101' },
    update: { name: 'U19' },
    create: {
      id: '00000000-0000-0000-0000-000000000101',
      name: 'U19',
      organizationId: organization.id,
    },
  });

  for (const roleType of Object.values(RoleType)) {
    await prisma.role.upsert({
      where: {
        organizationId_type: {
          organizationId: organization.id,
          type: roleType,
        },
      },
      update: {
        permissions: rolePermissions[roleType],
        name: roleType,
      },
      create: {
        organizationId: organization.id,
        type: roleType,
        name: roleType,
        permissions: rolePermissions[roleType],
      },
    });
  }

  const adminPasswordHash = await hash('ChangeMe123!', 10);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@pitchinsights.local' },
    update: {
      firstName: 'System',
      lastName: 'Admin',
      organizationId: organization.id,
      primaryTeamId: firstTeam.id,
      passwordHash: adminPasswordHash,
      active: true,
    },
    create: {
      email: 'admin@pitchinsights.local',
      passwordHash: adminPasswordHash,
      firstName: 'System',
      lastName: 'Admin',
      organizationId: organization.id,
      primaryTeamId: firstTeam.id,
      active: true,
      profile: { create: {} },
    },
  });

  const adminRole = await prisma.role.findUniqueOrThrow({
    where: {
      organizationId_type: {
        organizationId: organization.id,
        type: RoleType.ADMIN,
      },
    },
  });

  await prisma.userRole.upsert({
    where: {
      userId_roleId: {
        userId: admin.id,
        roleId: adminRole.id,
      },
    },
    update: {},
    create: {
      userId: admin.id,
      roleId: adminRole.id,
    },
  });

  await prisma.teamMembership.upsert({
    where: {
      teamId_userId: {
        teamId: firstTeam.id,
        userId: admin.id,
      },
    },
    update: {},
    create: {
      teamId: firstTeam.id,
      userId: admin.id,
    },
  });

  await prisma.teamQuota.upsert({
    where: { teamId: firstTeam.id },
    update: { quotaBytes: BigInt(5 * 1024 * 1024 * 1024) },
    create: {
      teamId: firstTeam.id,
      quotaBytes: BigInt(5 * 1024 * 1024 * 1024),
      usedBytes: BigInt(0),
    },
  });
}

main()
  .catch(async (error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
