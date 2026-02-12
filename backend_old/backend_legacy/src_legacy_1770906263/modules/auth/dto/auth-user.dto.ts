export class AuthUserDto {
    id!: string;
    email!: string;
    organizationId?: string | null;
    createdAt!: Date;
}
