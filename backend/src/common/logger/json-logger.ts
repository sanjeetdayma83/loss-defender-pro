import { LoggerService, LogLevel } from '@nestjs/common';

/** JSON-line logger (Pino-like without extra dep). Swap to pino later. */
export class JsonLogger implements LoggerService {
  private context?: string;
  constructor(context?: string) {
    this.context = context;
  }

  private write(level: string, message: any, ...optional: any[]) {
    const line = {
      ts: new Date().toISOString(),
      level,
      context: this.context,
      message: typeof message === 'string' ? message : JSON.stringify(message),
      meta: optional.length ? optional : undefined,
    };
    const out = JSON.stringify(line);
    if (level === 'error') console.error(out);
    else if (level === 'warn') console.warn(out);
    else console.log(out);
  }

  log(message: any, ...optional: any[]) {
    this.write('info', message, ...optional);
  }
  error(message: any, ...optional: any[]) {
    this.write('error', message, ...optional);
  }
  warn(message: any, ...optional: any[]) {
    this.write('warn', message, ...optional);
  }
  debug?(message: any, ...optional: any[]) {
    this.write('debug', message, ...optional);
  }
  verbose?(message: any, ...optional: any[]) {
    this.write('verbose', message, ...optional);
  }
  setLogLevels?(levels: LogLevel[]) {}
}
