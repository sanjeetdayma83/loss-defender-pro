import { EvidenceModule } from '../evidence/evidence.module';
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { RecordingsService } from './recordings.service';
import { RecordingsController } from './recordings.controller';
import { StorageModule } from '../storage/storage.module';
import { QUEUE_EVIDENCE } from '../queues/queue.constants';

@Module({
  imports: [StorageModule, EvidenceModule, BullModule.registerQueue({ name: QUEUE_EVIDENCE })],
  controllers: [RecordingsController],
  providers: [RecordingsService],
  exports: [RecordingsService],
})
export class RecordingsModule {}