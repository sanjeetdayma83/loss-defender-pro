import { NestFactory } from '@nestjs/core';

// Prisma BigInt → JSON string
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};
import { ValidationPipe } from '@nestjs/common';

// Prisma BigInt → JSON string
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};
import { AppModule } from './app.module';

// Prisma BigInt → JSON string
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';

// Prisma BigInt → JSON string
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

// Prisma BigInt → JSON string
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

// Prisma BigInt → JSON string
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const swaggerConfig = new DocumentBuilder()
  .setTitle('Loss Defender Pro API')
  .setDescription('Warehouse intelligence — /api/v1')
  .setVersion('1.0')
  .addBearerAuth()
  .build();
const document = SwaggerModule.createDocument(app, swaggerConfig);
SwaggerModule.setup('api/docs', app, document);

  app.enableCors({
    origin: true,
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
      forbidNonWhitelisted: false,
    }),
  );

  app.useGlobalInterceptors(
    new LoggingInterceptor(),
    new TransformInterceptor(),
  );

  const port = process.env.PORT ? Number(process.env.PORT) : 3000;
  await app.listen(port);
  console.log(`Loss Defender Pro API running on :${port}/api/v1`);
}

bootstrap();
