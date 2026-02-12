export interface ApiError {
  code: string;
  message: string;
  details: unknown | null;
}

export interface ApiMeta {
  requestId: string;
  timestamp: string;
  version: 'v1';
}

export interface ApiEnvelope<T> {
  success: boolean;
  data: T | null;
  error: ApiError | null;
  meta: ApiMeta;
}
