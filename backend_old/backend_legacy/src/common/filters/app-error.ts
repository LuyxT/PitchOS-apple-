import { HttpException, HttpStatus } from '@nestjs/common';

export class AppError extends HttpException {
  constructor(
    public readonly code: string,
    message: string,
    public readonly details: unknown = null,
    status: HttpStatus = HttpStatus.BAD_REQUEST,
  ) {
    super({ code, message, details }, status);
  }
}
