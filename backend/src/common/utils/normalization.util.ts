export function normalizeForMatch(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, '');
}

export function normalizeInviteCode(value: string): string {
  return value.trim().toUpperCase().replace(/\s+/g, '');
}
