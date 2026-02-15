-- AlterTable: expand PersonProfile to store rich role-specific profile data
ALTER TABLE "PersonProfile" ADD COLUMN "linkedPlayerID" TEXT;
ALTER TABLE "PersonProfile" ADD COLUMN "linkedAdminPersonID" TEXT;
ALTER TABLE "PersonProfile" ADD COLUMN "player" JSONB;
ALTER TABLE "PersonProfile" ADD COLUMN "headCoach" JSONB;
ALTER TABLE "PersonProfile" ADD COLUMN "assistantCoach" JSONB;
ALTER TABLE "PersonProfile" ADD COLUMN "athleticCoach" JSONB;
ALTER TABLE "PersonProfile" ADD COLUMN "medical" JSONB;
ALTER TABLE "PersonProfile" ADD COLUMN "teamManager" JSONB;
ALTER TABLE "PersonProfile" ADD COLUMN "board" JSONB;
ALTER TABLE "PersonProfile" ADD COLUMN "facility" JSONB;
ALTER TABLE "PersonProfile" ADD COLUMN "lockedFieldKeys" JSONB NOT NULL DEFAULT '[]';
ALTER TABLE "PersonProfile" ADD COLUMN "updatedBy" TEXT NOT NULL DEFAULT 'System';

-- Drop the old roleSpecific column (data migrated into typed columns above)
ALTER TABLE "PersonProfile" DROP COLUMN "roleSpecific";
