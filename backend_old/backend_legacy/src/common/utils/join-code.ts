import { createHash, randomBytes, timingSafeEqual } from 'crypto';

const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const NUMBERS = '23456789';

export function generateJoinCode(): string {
  const letters = Array.from({ length: 4 }, () => LETTERS[randomBytes(1)[0] % LETTERS.length]).join('');
  const numbers = Array.from({ length: 4 }, () => NUMBERS[randomBytes(1)[0] % NUMBERS.length]).join('');
  return `${letters}-${numbers}`;
}

export function hashJoinCode(code: string, pepper: string): string {
  return createHash('sha256').update(`${code.toUpperCase()}::${pepper}`).digest('hex');
}

export function compareJoinCode(code: string, hash: string, pepper: string): boolean {
  const candidate = Buffer.from(hashJoinCode(code, pepper), 'hex');
  const target = Buffer.from(hash, 'hex');
  if (candidate.length !== target.length) {
    return false;
  }
  return timingSafeEqual(candidate, target);
}
