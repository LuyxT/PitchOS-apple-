-- Add club metadata to Organization
ALTER TABLE "Organization"
  ADD COLUMN IF NOT EXISTS "nameNormalized" TEXT,
  ADD COLUMN IF NOT EXISTS "region" TEXT,
  ADD COLUMN IF NOT EXISTS "city" TEXT,
  ADD COLUMN IF NOT EXISTS "postalCode" TEXT,
  ADD COLUMN IF NOT EXISTS "clubFingerprint" TEXT,
  ADD COLUMN IF NOT EXISTS "inviteCode" TEXT,
  ADD COLUMN IF NOT EXISTS "verified" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "createdByUserId" TEXT;

-- Organization indexes
CREATE INDEX IF NOT EXISTS "Organization_nameNormalized_region_idx" ON "Organization" ("nameNormalized", "region");
CREATE UNIQUE INDEX IF NOT EXISTS "Organization_inviteCode_key" ON "Organization" ("inviteCode");
CREATE UNIQUE INDEX IF NOT EXISTS "Organization_clubFingerprint_unique" ON "Organization" ("clubFingerprint")
  WHERE ("postalCode" IS NOT NULL OR "city" IS NOT NULL);

-- Add normalized fields to Team
ALTER TABLE "Team"
  ADD COLUMN IF NOT EXISTS "nameNormalized" TEXT,
  ADD COLUMN IF NOT EXISTS "league" TEXT;

-- Replace team unique index with normalized variant
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'Team_organizationId_name_key'
  ) THEN
    EXECUTE 'DROP INDEX "Team_organizationId_name_key"';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS "Team_organizationId_nameNormalized_key" ON "Team" ("organizationId", "nameNormalized");

-- Allow users without organization during onboarding
ALTER TABLE "User" ALTER COLUMN "organizationId" DROP NOT NULL;

-- Ensure refresh token hashes are unique
CREATE UNIQUE INDEX IF NOT EXISTS "RefreshToken_tokenHash_key" ON "RefreshToken" ("tokenHash");

-- Memberships table
CREATE TABLE IF NOT EXISTS "Membership" (
  "id" TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  "organizationId" TEXT NOT NULL,
  "teamId" TEXT,
  "role" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "createdAt" TIMESTAMP NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT "Membership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE,
  CONSTRAINT "Membership_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE,
  CONSTRAINT "Membership_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "Membership_organizationId_idx" ON "Membership" ("organizationId");
CREATE INDEX IF NOT EXISTS "Membership_teamId_idx" ON "Membership" ("teamId");
CREATE UNIQUE INDEX IF NOT EXISTS "Membership_user_org_team_role_key" ON "Membership" ("userId", "organizationId", COALESCE("teamId", '00000000-0000-0000-0000-000000000000'), "role");

-- Onboarding state table
CREATE TABLE IF NOT EXISTS "OnboardingState" (
  "userId" TEXT PRIMARY KEY,
  "completed" BOOLEAN NOT NULL DEFAULT false,
  "completedAt" TIMESTAMP,
  "lastStep" TEXT,
  "createdAt" TIMESTAMP NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT "OnboardingState_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "OnboardingState_completed_idx" ON "OnboardingState" ("completed");
