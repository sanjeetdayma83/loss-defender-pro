import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

const SENSITIVE = [
  'password',
  'passwordHash',
  'tempPassword',
  'temporaryPassword',
  'devCode',
  'inviteToken',
  'refreshToken',
  'secret',
  'webhookSecret',
  'accessToken_raw',
];

function strip(obj: any, allowDevSecrets: boolean): any {
  if (obj == null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map((v) => strip(v, allowDevSecrets));
  const out: any = {};
  for (const [k, v] of Object.entries(obj)) {
    const lower = k.toLowerCase();
    const isDevSecret = ['devcode', 'temppassword', 'temporarypassword', 'invitetoken'].includes(lower);
    if (SENSITIVE.some((field) => field.toLowerCase() === lower)) {
      if (isDevSecret && allowDevSecrets) out[k] = strip(v, allowDevSecrets);
      continue;
    }
    out[k] = strip(v, allowDevSecrets);
  }
  return out;
}

@Injectable()
export class SanitizeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const path = String(req?.url ?? '');
    const isAuthTokenRoute = /\/auth\/(login|refresh)/i.test(path);
    const allowDevSecrets =
      process.env.ALLOW_DEV_SECRETS === 'true' &&
      process.env.NODE_ENV !== 'production';

    return next.handle().pipe(
      map((data) => {
        if (isAuthTokenRoute) {
          return strip(data, allowDevSecrets);
        }
        return strip(data, allowDevSecrets);
      }),
    );
  }
}