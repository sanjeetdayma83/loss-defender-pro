import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { AuditService } from './audit.service';

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(private readonly audit: AuditService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const method = String(req.method ?? 'GET').toUpperCase();
    const path = String(req.originalUrl ?? req.url ?? '');
    const skip = method === 'GET' || path.includes('/health') || path.includes('/docs') || path.includes('/webhooks/');
    if (skip) return next.handle();

    const user = req.user;
    const companyId = user?.companyId;
    if (!companyId) return next.handle();

    const action = `${method.toLowerCase()}:${path.replace(/\?.*$/, '')}`;
    const actorId = user?.id ?? user?.sub ?? null;
    const ip = req.ip ?? req.headers?.['x-forwarded-for'] ?? null;
    const userAgent = req.headers?.['user-agent'] ?? null;

    return next.handle().pipe(tap(async (response) => {
      try {
        await this.audit.log({
          companyId,
          actorId,
          action,
          entity: context.getClass().name,
          entityId: req.params?.id ?? null,
          meta: { statusCode: context.switchToHttp().getResponse().statusCode, requestId: req.id ?? req.headers?.['x-request-id'] ?? null },
          ipAddress: Array.isArray(ip) ? ip[0] : ip,
          userAgent,
          after: response && typeof response === 'object' ? { ok: true } : null,
        });
      } catch (_) {}
    }));
  }
}
