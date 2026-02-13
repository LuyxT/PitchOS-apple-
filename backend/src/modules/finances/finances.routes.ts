import { Router } from 'express';
import { authenticate } from '../../middleware/authMiddleware';

export function financesRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.get('/', authenticate(jwtAccessSecret), (_req, res) => {
    res.status(200).json({ message: 'Finances module — not yet implemented', data: [] });
  });

  return router;
}
