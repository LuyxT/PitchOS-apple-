import jwt from 'jsonwebtoken';
import crypto from 'crypto';

export interface AccessTokenPayload {
  userId: string;
  email: string;
  role: 'trainer' | 'player' | 'board';
}

export function signAccessToken(
  payload: AccessTokenPayload,
  secret: string,
  expiresIn: string
): string {
  return jwt.sign(payload, secret, { expiresIn: expiresIn as unknown as number });
}

export function verifyAccessToken(token: string, secret: string): AccessTokenPayload {
  const decoded = jwt.verify(token, secret);
  const payload = decoded as AccessTokenPayload & { iat?: number; exp?: number };
  return {
    userId: payload.userId,
    email: payload.email,
    role: payload.role,
  };
}

export function signRefreshToken(
  payload: { userId: string; tokenId: string },
  secret: string,
  expiresIn: string
): string {
  return jwt.sign(payload, secret, { expiresIn: expiresIn as unknown as number });
}

export function verifyRefreshToken(
  token: string,
  secret: string
): { userId: string; tokenId: string } {
  const decoded = jwt.verify(token, secret);
  const payload = decoded as { userId: string; tokenId: string };
  return {
    userId: payload.userId,
    tokenId: payload.tokenId,
  };
}

export function generateTokenId(): string {
  return crypto.randomUUID();
}
