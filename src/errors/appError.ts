import { Lg } from '@/utils/debugLog';

export enum AppErrorSeverity {
  CRITICAL = 'CRITICAL',
  HIGH = 'HIGH',
  MEDIUM = 'MEDIUM',
  LOW = 'LOW',
}

export enum AppErrorCode {
  NOT_FOUND = 'NOT_FOUND',
  INVALID_INPUT = 'INVALID_INPUT',
  DATABASE_FAILURE = 'DATABASE_FAILURE',
  OPERATION_FAILED = 'OPERATION_FAILED',
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  TIMEOUT = 'TIMEOUT',
}

export abstract class AppError extends Error {
  public readonly code: string;
  public readonly details?: any;
  public readonly timestamp: string;
  public readonly severity: AppErrorSeverity;
  public readonly module: string;

  constructor(
    module: string,
    code: string,
    message: string,
    severity: AppErrorSeverity = AppErrorSeverity.MEDIUM,
    details?: any,
  ) {
    super(message);
    this.name = this.constructor.name;
    this.module = module;
    this.code = code;
    this.message = message;
    this.details = details;
    this.severity = severity;
    this.timestamp = new Date().toISOString();
    Error.captureStackTrace?.(this, this.constructor);
  }

  public toJSON(): Record<string, any> {
    return {
      name: this.name,
      module: this.module,
      code: this.code,
      message: this.message,
      severity: this.severity,
      timestamp: this.timestamp,
      details: this.details,
      stack: this.stack,
    };
  }

  public log(): void {
    Lg.e(
      this.code,
      {
        message: this.message,
        severity: this.severity,
        module: this.module,
        timestamp: this.timestamp,
        details: this.details,
        stack: this.stack,
      },
      {
        category: this.module,
        collapse: true,
      },
    );
    // Example: Sentry.captureException(this);
  }

  public isCode(code: string): boolean {
    return this.code === code;
  }

  public isSeverity(severity: AppErrorSeverity): boolean {
    return this.severity === severity;
  }

  public getUserMessage(): string {
    return this.message;
  }

  public static wrap(
    module: string,
    error: unknown,
    defaultCode: string = AppErrorCode.OPERATION_FAILED,
    defaultMessage: string = 'An unexpected error occurred',
    severity: AppErrorSeverity = AppErrorSeverity.MEDIUM,
  ): AppError {
    if (error instanceof AppError) {
      return error;
    }
    return new GenericAppError(
      module,
      defaultCode,
      error instanceof Error ? error.message : defaultMessage,
      severity,
      { originalError: error },
    );
  }
}

class GenericAppError extends AppError {
  constructor(
    module: string,
    code: string,
    message: string,
    severity: AppErrorSeverity,
    details?: any,
  ) {
    super(module, code, message, severity, details);
    this.name = 'GenericAppError';
  }
}
