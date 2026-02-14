import { Router, Request, Response } from 'express';
import { authenticate } from '../../middleware/authMiddleware';
import { asyncHandler } from '../../middleware/asyncHandler';
import { getPrisma } from '../../lib/prisma';

export function financesRoutes(jwtAccessSecret: string): Router {
  const router = Router();
  const auth = authenticate(jwtAccessSecret);

  // GET /finance/entries — legacy compat endpoint
  router.get('/entries', auth, asyncHandler(async (req: Request, res: Response) => {
    const userId = req.auth!.userId;
    const prisma = getPrisma();

    const transactions = await prisma.cashTransaction.findMany({
      where: { userId },
      orderBy: { date: 'desc' },
    });

    const entries = transactions.map((t) => ({
      id: t.id,
      clubId: null,
      amount: t.amount,
      date: t.date.toISOString(),
      type: t.type,
      title: t.description,
      createdAt: t.createdAt.toISOString(),
      updatedAt: t.updatedAt.toISOString(),
    }));

    res.json(entries);
  }));

  // POST /finance/entry — legacy compat create
  router.post('/entry', auth, asyncHandler(async (req: Request, res: Response) => {
    const userId = req.auth!.userId;
    const prisma = getPrisma();
    const { amount, type, title, date } = req.body;

    // Ensure a default category exists
    let category = await prisma.cashCategory.findFirst({
      where: { userId, name: 'General' },
    });
    if (!category) {
      category = await prisma.cashCategory.create({
        data: { userId, name: 'General', colorHex: '#888888' },
      });
    }

    const transaction = await prisma.cashTransaction.create({
      data: {
        userId,
        amount: amount ?? 0,
        type: type ?? 'EXPENSE',
        description: title ?? 'Eintrag',
        date: date ? new Date(date) : new Date(),
        categoryId: category.id,
      },
    });

    res.status(201).json({
      id: transaction.id,
      clubId: null,
      amount: transaction.amount,
      date: transaction.date.toISOString(),
      type: transaction.type,
      title: transaction.description,
      createdAt: transaction.createdAt.toISOString(),
      updatedAt: transaction.updatedAt.toISOString(),
    });
  }));

  return router;
}
