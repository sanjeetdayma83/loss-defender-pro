export function validateEnv() {
  const isProd = process.env.NODE_ENV === 'production';
  const errors: string[] = [];

  const access = process.env.JWT_ACCESS_SECRET || process.env.JWT_SECRET || '';
  const refresh = process.env.JWT_REFRESH_SECRET || '';

  if (isProd) {
    if (!access || access.length < 32 || /change-me|dev-access/i.test(access)) {
      errors.push('JWT_ACCESS_SECRET must be a strong non-placeholder value >= 32 chars in production');
    }
    if (!refresh || refresh.length < 32 || /change-me|dev-refresh/i.test(refresh)) {
      errors.push('JWT_REFRESH_SECRET must be a strong non-placeholder value >= 32 chars in production');
    }
    if (!process.env.DATABASE_URL) errors.push('DATABASE_URL is required');

    const b2Key = process.env.B2_KEY_ID;
    const b2Secret = process.env.B2_APPLICATION_KEY || process.env.B2_APP_KEY;
    const b2Bucket = process.env.B2_BUCKET || process.env.B2_BUCKET_NAME;
    const b2Endpoint = process.env.B2_ENDPOINT;
    if (!b2Key || !b2Secret || !b2Bucket || !b2Endpoint) {
      errors.push('B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET and B2_ENDPOINT are required in production');
    }

    if (!(process.env.CORS_ORIGINS || '').trim()) {
      errors.push('CORS_ORIGINS required in production (comma-separated)');
    }

    const webhookSecret = process.env.WEBHOOK_SECRET || '';
    if (webhookSecret.length < 32 || /test-webhook|change-me|placeholder/i.test(webhookSecret)) {
      errors.push('WEBHOOK_SECRET must be a strong non-placeholder value >= 32 chars in production');
    }

    if (process.env.ALLOW_DEV_SECRETS === 'true') {
      errors.push('ALLOW_DEV_SECRETS must not be true in production');
    }

    const signedTtl = Number(process.env.B2_SIGNED_URL_TTL || 900);
    if (!Number.isFinite(signedTtl) || signedTtl < 60 || signedTtl > 900) {
      errors.push('B2_SIGNED_URL_TTL must be between 60 and 900 seconds');
    }
  } else {
    if (access && access.length < 16) console.warn('[env] JWT_ACCESS_SECRET is short — use 32+ chars');
  }

  if (errors.length) throw new Error(`Invalid environment:\n- ${errors.join('\n- ')}`);
}