export class AuthResponseDto {
  accessToken!: string;
  refreshToken!: string;
  expiresIn!: string;
  tokenType!: 'Bearer';
  user?: {
    id: string;
    email: string;
    organizationId?: string | null;
    createdAt: Date;
  };
}
