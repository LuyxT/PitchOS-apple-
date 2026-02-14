import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './cash.controller';

export function cashRoutes(jwtAccessSecret: string): Router {
  const router = Router();
  const auth = authenticate(jwtAccessSecret);

  // Bootstrap — returns categories, transactions, contributions, goals
  router.get('/bootstrap', auth, asyncHandler(ctrl.bootstrapController));

  // Transactions
  router.get('/transactions', auth, asyncHandler(ctrl.listTransactionsController));
  router.post('/transactions', auth, asyncHandler(ctrl.createTransactionController));
  router.put('/transactions/:id', auth, asyncHandler(ctrl.updateTransactionController));
  router.delete('/transactions/:id', auth, asyncHandler(ctrl.deleteTransactionController));

  // Contributions
  router.post('/contributions', auth, asyncHandler(ctrl.createContributionController));
  router.put('/contributions/:id', auth, asyncHandler(ctrl.updateContributionController));
  router.post('/contributions/reminder', auth, asyncHandler(ctrl.sendContributionReminderController));

  // Goals
  router.post('/goals', auth, asyncHandler(ctrl.createGoalController));
  router.put('/goals/:id', auth, asyncHandler(ctrl.updateGoalController));
  router.delete('/goals/:id', auth, asyncHandler(ctrl.deleteGoalController));

  return router;
}
