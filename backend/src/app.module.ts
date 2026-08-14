import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { SupportModule } from './support/support.module';
import { RbacModule } from './common/rbac/rbac.module';
import { BillingModule } from './billing/billing.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { RequestIdMiddleware } from './common/middleware/request-id.middleware';
import { MiddlewareConsumer, NestModule, Module } from '@nestjs/common';

import { ConfigModule, ConfigService } from '@nestjs/config';
import configuration from './config/configuration';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { AuditModule } from './audit/audit.module';
import { CompaniesModule } from './companies/companies.module';
import { WarehousesModule } from './warehouses/warehouses.module';
import { UsersModule } from './users/users.module';
import { OrdersModule } from './orders/orders.module';
import { StorageModule } from './storage/storage.module';
import { HealthModule } from './health/health.module';
import { RecordingsModule } from './recordings/recordings.module';
import { EvidenceModule } from './evidence/evidence.module';
import { ClaimsModule } from './claims/claims.module';
import { ReturnsModule } from './returns/returns.module';
import { ScannerModule } from './scanner/scanner.module';
import { AlertsModule } from './alerts/alerts.module';
import { EmailModule } from './email/email.module';
import { QueuesModule } from './queues/queues.module';
import { MarketplaceModule } from './marketplace/marketplace.module';
import { NotificationsModule } from './notifications/notifications.module';
import { RealtimeModule } from './realtime/realtime.module';
import { FrameExtractorModule } from './frame-extractor/frame-extractor.module';
import { RedisThrottlerStorage } from '@nestjs-redis/throttler-storage';
import Redis from 'ioredis';

@Module({
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    ThrottlerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        throttlers: [
          {
            ttl: 60000,
            limit: 100,
            storage: new RedisThrottlerStorage(new Redis(config.get<string>('redis.url'))),
          },
        ],
      }),
    }),
    PrismaModule,
    EmailModule,
    QueuesModule,
    RealtimeModule,
    AuditModule,
    AuthModule,
    CompaniesModule,
    WarehousesModule,
    UsersModule,
    OrdersModule,
    StorageModule,
    HealthModule,
    RecordingsModule,
    EvidenceModule,
    ClaimsModule,
    ReturnsModule,
    ScannerModule,
    AlertsModule,
    MarketplaceModule, AnalyticsModule, BillingModule, SupportModule,
    NotificationsModule,
    FrameExtractorModule,
  ],
  
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}