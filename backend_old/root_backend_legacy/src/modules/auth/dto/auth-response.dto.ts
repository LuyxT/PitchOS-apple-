export class AuthResponseDto {
  accessToken!: string;
  refreshToken!: string;
  expiresIn!: string;
  tokenType!: 'Bearer';
}
