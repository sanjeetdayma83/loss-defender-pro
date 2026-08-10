import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

const SENSITIVE = [
  'tempPassword', 'temporaryPassword', 'devCode',
  'password', 'passwordHash', 'accessToken_raw',
];

function strip(obj: any): any {
  if (obj == null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(strip);
  const out: any = {};
  for (const [k, v] of Object.entries(obj)) {
    if (process.env.NODE_ENV === 'production' && SENSITIVE.includes(k)) continue;
    out[k] = strip(v);
  }
  return out;
}

@Injectable()
export class SanitizeInterceptor implements NestInterceptor {
  intercept(_ctx: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(map((data) => strip(data)));
  }
}
