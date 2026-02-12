export interface ApiError {
  code: string;
  message: string;
  details?: unknown;
}

export interface ApiEnvelope<T> {
  success: boolean;
  data: T | null;
  error: ApiError | null;
}

export function isApiEnvelope(value: unknown): value is ApiEnvelope<unknown> {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const candidate = value as Partial<ApiEnvelope<unknown>>;
  return (
    typeof candidate.success === 'boolean' &&
    'data' in candidate &&
    'error' in candidate
  );
}
