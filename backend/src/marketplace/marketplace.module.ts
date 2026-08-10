import { Module } from '@nestjs/common';
import { MarketplaceService } from './marketplace.service';
import { MarketplaceController } from './marketplace.controller';
import { MarketplaceCryptoService } from './marketplace-crypto.service';
import { PrismaModule } from '../prisma/prisma.module';
@Module({imports:[PrismaModule],controllers:[MarketplaceController],providers:[MarketplaceService,MarketplaceCryptoService],exports:[MarketplaceService]})
export class MarketplaceModule {}
