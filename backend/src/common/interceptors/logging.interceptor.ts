import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const method = req?.method ?? 'UNKNOWN';
    const url = req?.url ?? '';
    const user = req?.user?.sub ?? 'anon';
    const tenant = req?.tenantId ?? req?.user?.companyId ?? '-';
    const started = Date.now();

    return next.handle().pipe(
      tap({
        next: () => {
          this.logger.log(
            `${method} ${url} ${Date.now() - started}ms user=${user} tenant=${tenant}`,
          );
        },
        error: (err: any) => {
          this.logger.warn(
            `${method} ${url} ${Date.now() - started}ms user=${user} tenant=${tenant} err=${err?.message}`,
          );
        },
      }),
    );
  }
}
