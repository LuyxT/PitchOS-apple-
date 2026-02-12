type LogLevel = 'info' | 'warn' | 'error';

export function structuredLog(
  level: LogLevel,
  message: string,
  metadata: Record<string, unknown> = {},
): void {
  const line = {
    level,
    message,
    timestamp: new Date().toISOString(),
    ...metadata,
  };

  const output = JSON.stringify(line);

  if (level === 'error') {
    console.error(output);
    return;
  }

  if (level === 'warn') {
    console.warn(output);
    return;
  }

  console.log(output);
}
