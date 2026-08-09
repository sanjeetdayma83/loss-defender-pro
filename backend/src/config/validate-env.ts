export function validateEnv() {
  const isProd = process.env.NODE_ENV === 'production';
  const errors: string[] = [];

  const access =
    process.env.JWT_ACCESS_SECRET || process.env.JWT_SECRET || '';
  const refresh = process.env.JWT_REFRESH_SECRET || '';

  if (isProd) {
    if (!access || access.length < 32) {
      errors.push('JWT_ACCESS_SECRET must be set and >= 32 chars in production');
    }
    if (!refresh || refresh.length < 32) {
      errors.push('JWT_REFRESH_SECRET must be set and >= 32 chars in production');
    }
    if (!process.env.DATABASE_URL) {
      errors.push('DATABASE_URL is required');
    }
    const b2Key = process.env.B2_KEY_ID;
    const b2Secret =
      process.env.B2_APPLICATION_KEY || process.env.B2_APP_KEY;
    const b2Bucket = process.env.B2_BUCKET || process.env.B2_BUCKET_NAME;
    if (!b2Key || !b2Secret || !b2Bucket) {
      errors.push('B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET required in production');
    }
    if (!(process.env.CORS_ORIGINS || '').trim()) {
      errors.push('CORS_ORIGINS required in production (comma-separated)');
    }
  } else {
    if (access && access.length < 16) {
      console.warn('[env] JWT_ACCESS_SECRET is short — use 32+ chars');
    }
  }

  if (errors.length) {
    throw new Error(`Invalid environment:\n- ${errors.join('\n- ')}`);
  }
}