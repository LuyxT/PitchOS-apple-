const DURATION_REGEX = /^(\d+)(ms|s|m|h|d)$/;

export function parseDurationToMs(value: string, fallbackMs: number): number {
  const match = DURATION_REGEX.exec(value.trim());

  if (!match) {
    return fallbackMs;
  }

  const amount = Number(match[1]);
  const unit = match[2];

  const multipliers: Record<string, number> = {
    ms: 1,
    s: 1_000,
    m: 60_000,
    h: 3_600_000,
    d: 86_400_000,
  };

  const multiplier = multipliers[unit];
  return Number.isFinite(amount) ? amount * multiplier : fallbackMs;
}
