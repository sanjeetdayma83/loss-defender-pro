import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { AuditService } from '../../audit/audit.service';

// Skeleton: writes a coarse audit entry for mutating requests on decorated controllers.
// Attach via @UseInterceptors(AuditLogInterceptor) once you add per-module before/after
// state capture (this scaffold intentionally keeps it generic).
@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  constructor(private readonly auditService: AuditService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const isMutating = ['POST', 'PATCH', 'PUT', 'DELETE'].includes(req.method);

    return next.handle().pipe(
      tap(() => {
        if (!isMutating || !req.user?.companyId) return;
        this.auditService
          .log({
            companyId: req.user.companyId,
            actorId: req.user.sub,
            action: `${req.method} ${req.route?.path ?? req.url}`,
            entity: req.route?.path?.split('/')[1] ?? 'unknown',
            ipAddress: req.ip,
          })
          .catch(() => void 0); // audit failures must never break the request
      }),
    );
  }
}
