import {
  Injectable, NestInterceptor, ExecutionContext, CallHandler, Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  private readonly log = new Logger('Audit');
  constructor(private readonly prisma: PrismaService) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<any> {
    const req = ctx.switchToHttp().getRequest();
    const method = (req.method || '').toUpperCase();
    if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
      return next.handle();
    }
    const user = req.user;
    const path = req.route?.path || req.url;
    return next.handle().pipe(
      tap({
        next: async () => {
          try {
            if (!user?.companyId) return;
            await this.prisma.auditLog.create({
              data: {
                companyId: user.companyId,
                userId: user.sub || user.userId || null,
                action: `${method} ${path}`,
                entity: path?.split('/')?.[1] || 'api',
                metadata: { ip: req.ip },
              } as any,
            });
          } catch (e: any) {
            this.log.warn(`audit skip: ${e?.message}`);
          }
        },
      }),
    );
  }
}
