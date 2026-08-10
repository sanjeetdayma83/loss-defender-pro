import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { MarketplaceService } from './marketplace.service';
import { QUEUE_MARKETPLACE_SYNC } from './marketplace-sync.constants';

@Injectable()
@Processor(QUEUE_MARKETPLACE_SYNC)
export class MarketplaceSyncProcessor extends WorkerHost {
  private readonly logger = new Logger(MarketplaceSyncProcessor.name);

  constructor(private readonly marketplace: MarketplaceService) {
    super();
  }

  async process(job: Job<{ companyId: string; provider: string }>) {
    const { companyId, provider } = job.data;
    this.logger.log(`marketplace sync ${job.id}: ${provider}/${companyId}`);
    const result = await this.marketplace.syncOrders(companyId, provider);
    this.logger.log(`marketplace sync ${job.id} completed: ${JSON.stringify(result)}`);
    return result;
  }
}
