import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class OnboardingResolveDto {
    @IsString()
    @IsIn(['trainer', 'co_trainer', 'physio', 'vorstand'])
    role!: string;

    @IsString()
    @MinLength(2)
    region!: string;

    @IsString()
    @MinLength(2)
    clubName!: string;

    @IsOptional()
    @IsString()
    postalCode?: string;

    @IsOptional()
    @IsString()
    city?: string;

    @IsOptional()
    @IsString()
    teamName?: string;

    @IsOptional()
    @IsString()
    league?: string;

    @IsOptional()
    @IsString()
    inviteCode?: string;

    @IsOptional()
    @IsString()
    clubId?: string;
}
