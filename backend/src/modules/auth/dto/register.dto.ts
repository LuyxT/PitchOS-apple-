import { IsEmail, IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class RegisterDto {
    @IsEmail()
    email!: string;

    @IsString()
    @MinLength(8)
    password!: string;

    @IsString()
    @MinLength(8)
    passwordConfirmation!: string;

    @IsString()
    @IsIn(['trainer', 'co_trainer', 'physio', 'vorstand', 'player'])
    role!: string;

    @IsOptional()
    @IsString()
    inviteCode?: string;
}
