const configuration = () => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  database: { url: process.env.DATABASE_URL },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET ?? process.env.JWT_SECRET ?? 'dev-access-secret-change-me',
    refreshSecret: process.env.JWT_REFRESH_SECRET ?? 'dev-refresh-secret-change-me',
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES ?? '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES ?? '7d',
  },
  redis: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
  b2: {
    keyId: process.env.B2_KEY_ID,
    appKey: process.env.B2_APPLICATION_KEY,
    bucketId: process.env.B2_BUCKET_ID,
    bucketName: process.env.B2_BUCKET_NAME,
    endpoint: process.env.B2_ENDPOINT,
  },
  app: { name: 'Loss Defender Pro', apiPrefix: 'api/v1' },
});

export default configuration;
export { configuration };
