import type { AuthTokenPayload } from '../config/jwt';

declare global {
  namespace Express {
    interface Request {
      auth?: AuthTokenPayload;
    }
  }
}

export {};
