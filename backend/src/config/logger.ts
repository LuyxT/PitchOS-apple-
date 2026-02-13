export function logInfo(message: string, context?: Record<string, unknown>): void {
  if (context) {
    console.log(JSON.stringify({ level: 'info', message, context }));
    return;
  }
  console.log(JSON.stringify({ level: 'info', message }));
}

export function logError(message: string, context?: Record<string, unknown>): void {
  if (context) {
    console.error(JSON.stringify({ level: 'error', message, context }));
    return;
  }
  console.error(JSON.stringify({ level: 'error', message }));
}
