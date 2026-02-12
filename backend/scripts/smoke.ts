import 'dotenv/config';

type Envelope<T> = {
  success: boolean;
  data: T | null;
  error: {
    code: string;
    message: string;
    details?: unknown;
  } | null;
};

const baseUrl =
  process.env.SMOKE_BASE_URL ??
  `http://127.0.0.1:${process.env.PORT ?? '3000'}`;

async function request<T>(
  method: string,
  path: string,
  options: { token?: string; body?: unknown } = {},
): Promise<T> {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const rawText = await response.text();
  let parsed: Envelope<T>;

  try {
    parsed = rawText
      ? (JSON.parse(rawText) as Envelope<T>)
      : ({
          success: false,
          data: null,
          error: { code: 'EMPTY', message: 'Empty response' },
        } as Envelope<T>);
  } catch {
    throw new Error(`Invalid JSON from ${path}: ${rawText}`);
  }

  if (!response.ok || !parsed.success || parsed.data === null) {
    throw new Error(
      `Request failed ${method} ${path}: status=${response.status} body=${JSON.stringify(parsed)}`,
    );
  }

  return parsed.data;
}

async function run(): Promise<void> {
  console.log(`[smoke] baseUrl=${baseUrl}`);

  await request<{ status: string }>('GET', '/api/v1/health');

  const email = `smoke_${Date.now()}@example.com`;
  const password = 'SmokeTest123!';

  await request<Record<string, unknown>>('POST', '/api/v1/auth/register', {
    body: {
      email,
      password,
      role: 'TRAINER',
      firstName: 'Smoke',
      lastName: 'Tester',
    },
  });

  const login = await request<{
    tokens: {
      accessToken: string;
    };
  }>('POST', '/api/v1/auth/login', {
    body: { email, password },
  });

  const token = login.tokens.accessToken;

  await request<Record<string, unknown>>('GET', '/api/v1/auth/me', { token });

  const club = await request<{
    club: {
      id: string;
      name: string;
    };
  }>('POST', '/api/v1/onboarding/club', {
    token,
    body: {
      name: `Smoke Club ${Date.now()}`,
      city: 'Test City',
      region: 'US',
    },
  });

  const team = await request<{
    team: {
      id: string;
    };
  }>('POST', '/api/v1/onboarding/team', {
    token,
    body: {
      clubId: club.club.id,
      name: 'A Team',
      ageGroup: 'U15',
      league: 'Regional',
    },
  });

  await request<Record<string, unknown>>('POST', '/api/v1/players', {
    token,
    body: {
      teamId: team.team.id,
      firstName: 'John',
      lastName: 'Doe',
      position: 'MID',
    },
  });

  await request<unknown[]>('GET', `/api/v1/players?teamId=${team.team.id}`, {
    token,
  });

  await request<Record<string, unknown>>('POST', '/api/v1/finance/entry', {
    token,
    body: {
      clubId: club.club.id,
      amount: 1250.55,
      type: 'INCOME',
      title: 'Membership Fee',
      date: new Date().toISOString(),
    },
  });

  await request<Record<string, unknown>>(
    'GET',
    `/api/v1/finance/bootstrap?clubId=${club.club.id}`,
    {
      token,
    },
  );

  await request<Record<string, unknown>>(
    'GET',
    `/api/v1/finance/cash/bootstrap?clubId=${club.club.id}`,
    {
      token,
    },
  );

  console.log('[smoke] SUCCESS');
}

run().catch((error) => {
  console.error(
    '[smoke] FAILED',
    error instanceof Error ? error.message : error,
  );
  process.exitCode = 1;
});
