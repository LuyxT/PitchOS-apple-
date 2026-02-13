import jwt from 'jsonwebtoken';

export type AuthTokenPayload = {
  userId: string;
  email: string;
  role: 'trainer' | 'player' | 'board';
};

const ACCESS_TOKEN_EXPIRES_IN = '7d';

export function signAccessToken(payload: AuthTokenPayload, secret: string): string {
  return jwt.sign(payload, secret, { expiresIn: ACCESS_TOKEN_EXPIRES_IN });
}

export function verifyAccessToken(token: string, secret: string): AuthTokenPayload {
  return jwt.verify(token, secret) as AuthTokenPayload;
}
