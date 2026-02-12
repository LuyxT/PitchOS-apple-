import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { OnboardingResolveDto } from './dto/onboarding-resolve.dto';
import { MembershipRole, MembershipStatus } from '@prisma/client';
import { createHash, randomBytes } from 'crypto';

interface ResolveResponse {
    mode: 'joined' | 'requested' | 'candidates';
    clubId?: string;
    teamId?: string | null;
    membershipStatus?: 'active' | 'pending';
    candidates?: Array<{
        clubId: string;
        clubName: string;
        city?: string | null;
        postalCode?: string | null;
        region?: string | null;
    }>;
    message?: string;
}

@Injectable()
export class OnboardingService {
    constructor(private readonly prisma: PrismaService) { }

    async resolve(userId: string, input: OnboardingResolveDto): Promise<ResolveResponse> {
        const role = this.mapRole(input.role);
        const requiresTeam = role !== MembershipRole.VORSTAND;
        if (requiresTeam && (!input.teamName || input.teamName.trim().length < 2)) {
            throw new BadRequestException('Team name is required for this role');
        }

        const region = input.region.trim();
        const clubName = input.clubName.trim();
        const nameNormalized = this.normalizeName(clubName);
        const city = input.city?.trim() || null;
        const postalCode = input.postalCode?.trim() || null;
        const teamName = input.teamName?.trim() || null;
        const teamNameNormalized = teamName ? this.normalizeName(teamName) : null;

        if (input.inviteCode) {
            const club = await this.prisma.organization.findFirst({
                where: { inviteCode: input.inviteCode.trim() },
            });
            if (!club) {
                throw new NotFoundException({ code: 'INVALID_INVITE', message: 'Invite code not found' });
            }
            return this.joinClub(userId, club.id, role, teamName, teamNameNormalized, input.league, true);
        }

        if (input.clubId) {
            const club = await this.prisma.organization.findUnique({ where: { id: input.clubId } });
            if (!club) {
                throw new NotFoundException({ code: 'CLUB_NOT_FOUND', message: 'Club not found' });
            }
            return this.joinClub(userId, club.id, role, teamName, teamNameNormalized, input.league, false);
        }

        const fingerprint = this.buildFingerprint(nameNormalized, region, postalCode, city);
        if (fingerprint) {
            const exact = await this.prisma.organization.findFirst({
                where: { clubFingerprint: fingerprint },
            });
            if (exact) {
                return this.joinClub(userId, exact.id, role, teamName, teamNameNormalized, input.league, false);
            }
        }

        const candidates = await this.findCandidates(nameNormalized, region);
        if (candidates.length > 1) {
            return {
                mode: 'candidates',
                candidates: candidates.map((club) => ({
                    clubId: club.id,
                    clubName: club.name,
                    city: club.city,
                    postalCode: club.postalCode,
                    region: club.region,
                })),
                message: 'Club already exists, select',
            };
        }

        if (candidates.length === 1) {
            return this.joinClub(userId, candidates[0].id, role, teamName, teamNameNormalized, input.league, false);
        }

        return this.createClub(userId, {
            name: clubName,
            nameNormalized,
            region,
            city,
            postalCode,
            fingerprint,
            teamName,
            teamNameNormalized,
            league: input.league ?? null,
            role,
        });
    }

    async complete(userId: string) {
        await this.prisma.onboardingState.upsert({
            where: { userId },
            update: { completed: true, completedAt: new Date(), lastStep: 'complete' },
            create: { userId, completed: true, completedAt: new Date(), lastStep: 'complete' },
        });
        return { success: true };
    }

    private async joinClub(
        userId: string,
        clubId: string,
        role: MembershipRole,
        teamName: string | null,
        teamNameNormalized: string | null,
        league: string | undefined | null,
        invited: boolean,
    ): Promise<ResolveResponse> {
        const teamId = await this.resolveTeam(clubId, role, teamName, teamNameNormalized, league);
        const status = role === MembershipRole.VORSTAND ? MembershipStatus.ACTIVE : (invited ? MembershipStatus.ACTIVE : MembershipStatus.PENDING);

        await this.prisma.membership.create({
            data: {
                userId,
                organizationId: clubId,
                teamId,
                role,
                status,
            },
        }).catch(() => undefined);

        await this.prisma.user.update({
            where: { id: userId },
            data: {
                organizationId: clubId,
                primaryTeamId: teamId ?? undefined,
            },
        });

        await this.prisma.onboardingState.upsert({
            where: { userId },
            update: { lastStep: 'club' },
            create: { userId, lastStep: 'club' },
        });

        return {
            mode: status === MembershipStatus.ACTIVE ? 'joined' : 'requested',
            clubId,
            teamId,
            membershipStatus: status === MembershipStatus.ACTIVE ? 'active' : 'pending',
        };
    }

    private async resolveTeam(
        clubId: string,
        role: MembershipRole,
        teamName: string | null,
        teamNameNormalized: string | null,
        league: string | undefined | null,
    ): Promise<string | null> {
        if (role === MembershipRole.VORSTAND) {
            return null;
        }
        if (!teamName || !teamNameNormalized) {
            throw new BadRequestException('Team name is required for this role');
        }

        const existing = await this.prisma.team.findFirst({
            where: {
                organizationId: clubId,
                nameNormalized: teamNameNormalized,
            },
        });

        if (existing) {
            return existing.id;
        }

        const created = await this.prisma.team.create({
            data: {
                organizationId: clubId,
                name: teamName,
                nameNormalized: teamNameNormalized,
                league: league ?? null,
            },
        });

        return created.id;
    }

    private async createClub(
        userId: string,
        input: {
            name: string;
            nameNormalized: string;
            region: string;
            city: string | null;
            postalCode: string | null;
            fingerprint: string | null;
            teamName: string | null;
            teamNameNormalized: string | null;
            league: string | null;
            role: MembershipRole;
        },
    ): Promise<ResolveResponse> {
        const inviteCode = await this.generateInviteCode();
        const club = await this.prisma.organization.create({
            data: {
                name: input.name,
                nameNormalized: input.nameNormalized,
                region: input.region,
                city: input.city,
                postalCode: input.postalCode,
                clubFingerprint: input.fingerprint,
                inviteCode,
                verified: false,
                createdByUserId: userId,
            },
        });

        const teamId = await this.resolveTeam(
            club.id,
            input.role,
            input.teamName,
            input.teamNameNormalized,
            input.league,
        );

        await this.prisma.membership.create({
            data: {
                userId,
                organizationId: club.id,
                teamId,
                role: input.role,
                status: MembershipStatus.ACTIVE,
            },
        });

        await this.prisma.user.update({
            where: { id: userId },
            data: {
                organizationId: club.id,
                primaryTeamId: teamId ?? undefined,
            },
        });

        await this.prisma.onboardingState.upsert({
            where: { userId },
            update: { lastStep: 'club' },
            create: { userId, lastStep: 'club' },
        });

        return {
            mode: 'joined',
            clubId: club.id,
            teamId,
            membershipStatus: 'active',
        };
    }

    private mapRole(role: string): MembershipRole {
        switch (role) {
            case 'trainer':
                return MembershipRole.TRAINER;
            case 'co_trainer':
                return MembershipRole.CO_TRAINER;
            case 'physio':
                return MembershipRole.PHYSIO;
            case 'vorstand':
                return MembershipRole.VORSTAND;
            default:
                throw new BadRequestException('Invalid role');
        }
    }

    private normalizeName(value: string): string {
        const normalized = value
            .toLowerCase()
            .replace(/[\.,\-_/]/g, ' ')
            .replace(/\s+/g, ' ')
            .replace(/\b(e\.?v\.?|ev)\b/g, '')
            .trim();

        const tokens = normalized.split(' ').filter(Boolean).map((token) => {
            if (['sv', 'vfb', 'tsv', 'fc', 'sc', 'sg', 'fv', 'tus', 'ssv'].includes(token)) {
                return token;
            }
            return token;
        });

        return tokens.join(' ');
    }

    private buildFingerprint(nameNormalized: string, region: string, postalCode: string | null, city: string | null): string | null {
        const location = postalCode || city;
        if (!location) {
            return null;
        }
        const payload = `${nameNormalized}|${region.toLowerCase().trim()}|${location.toLowerCase().trim()}`;
        return createHash('sha256').update(payload).digest('hex');
    }

    private async findCandidates(nameNormalized: string, region: string) {
        const clubs = await this.prisma.organization.findMany({
            where: {
                region: region,
                nameNormalized: { not: null },
            },
            take: 25,
        });

        return clubs
            .map((club) => ({
                ...club,
                score: this.similarity(nameNormalized, club.nameNormalized ?? ''),
            }))
            .filter((club) => club.score >= 0.6)
            .sort((a, b) => b.score - a.score)
            .slice(0, 5);
    }

    private similarity(a: string, b: string): number {
        if (!a || !b) return 0;
        if (a === b) return 1;
        const aTokens = new Set(a.split(' '));
        const bTokens = new Set(b.split(' '));
        const intersection = Array.from(aTokens).filter((token) => bTokens.has(token)).length;
        const union = new Set([...aTokens, ...bTokens]).size || 1;
        return intersection / union;
    }

    private async generateInviteCode(): Promise<string> {
        for (let i = 0; i < 5; i += 1) {
            const code = randomBytes(4).toString('hex').toUpperCase().slice(0, 6);
            const exists = await this.prisma.organization.findFirst({ where: { inviteCode: code } });
            if (!exists) {
                return code;
            }
        }
        return randomBytes(6).toString('hex').toUpperCase().slice(0, 6);
    }
}
