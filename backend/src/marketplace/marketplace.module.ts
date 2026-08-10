import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { MarketplaceService } from './marketplace.service';
import { MarketplaceController } from './marketplace.controller';
import { MarketplaceCryptoService } from './marketplace-crypto.service';
import { MarketplaceSyncProcessor } from './marketplace-sync.processor';
import { QUEUE_MARKETPLACE_SYNC } from './marketplace-sync.constants';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule, BullModule.registerQueue({ name: QUEUE_MARKETPLACE_SYNC })],
  controllers: [MarketplaceController],
  providers: [MarketplaceService, MarketplaceCryptoService, MarketplaceSyncProcessor],
  exports: [MarketplaceService, BullModule],
})
export class MarketplaceModule {}
