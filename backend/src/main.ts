import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { SanitizeInterceptor } from './common/interceptors/sanitize.interceptor';
import { validateEnv } from './config/validate-env';

// Prisma BigInt → JSON (once only)
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};

async function bootstrap() {
  validateEnv();

  const app = await NestFactory.create(AppModule);
  const isProd = process.env.NODE_ENV === 'production';

  app.use(
    helmet({
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Loss Defender Pro API')
    .setDescription('Warehouse intelligence — /api/v1')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  if (!isProd) {
    SwaggerModule.setup('api/docs', app, document);
  }

  const origins = (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  app.enableCors({
    origin: isProd
      ? origins.length
        ? origins
        : false
      : origins.length
        ? origins
        : true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'HEAD'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'Accept',
      'X-Requested-With',
      'X-Tenant-Id',
      'X-Request-Id',
    ],
  });

  app.setGlobalPrefix('api/v1');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  app.useGlobalInterceptors(
    new LoggingInterceptor(),
    new SanitizeInterceptor(),
    new TransformInterceptor(),
  );

  const port = process.env.PORT ? Number(process.env.PORT) : 3000;
  await app.listen(port);
  console.log(`Loss Defender Pro API running on :${port}/api/v1`);
}

bootstrap();