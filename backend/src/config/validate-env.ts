export function validateEnv() {
  const isProd = process.env.NODE_ENV === 'production';
  const errors: string[] = [];

  const access =
    process.env.JWT_ACCESS_SECRET || process.env.JWT_SECRET || '';
  const refresh = process.env.JWT_REFRESH_SECRET || '';

  const isWeak = (v: string) =>
    !v ||
    v.length < 32 ||
    /change-me|changeme|secret123|password|your[_-]?key|placeholder/i.test(v);

  if (isProd) {
    if (isWeak(access)) {
      errors.push(
        'JWT_ACCESS_SECRET must be set, >= 32 chars, and not a placeholder in production',
      );
    }
    if (isWeak(refresh)) {
      errors.push(
        'JWT_REFRESH_SECRET must be set, >= 32 chars, and not a placeholder in production',
      );
    }
    if (!process.env.DATABASE_URL) {
      errors.push('DATABASE_URL is required');
    }
    const b2Key = process.env.B2_KEY_ID || '';
    const b2Secret =
      process.env.B2_APPLICATION_KEY || process.env.B2_APP_KEY || '';
    const b2Bucket = process.env.B2_BUCKET || process.env.B2_BUCKET_NAME || '';
    if (!b2Key || !b2Secret || !b2Bucket || /PLACE|change-me/i.test(b2Key + b2Secret)) {
      errors.push('B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET required (real values) in production');
    }
    const cors = (process.env.CORS_ORIGINS || '').trim();
    if (!cors || cors === '*') {
      errors.push('CORS_ORIGINS required in production (explicit list, not *)');
    }
  } else {
    if (access && access.length < 16) {
      console.warn('[env] JWT_ACCESS_SECRET is short — use 32+ chars');
    }
    if (/change-me/i.test(access + refresh)) {
      console.warn('[env] JWT secrets look like placeholders — replace before production');
    }
  }

  if (errors.length) {
    throw new Error(`Invalid environment:\n- ${errors.join('\n- ')}`);
  }
}
