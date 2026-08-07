import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
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

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    PrismaModule,
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
  ],
})
export class AppModule {}