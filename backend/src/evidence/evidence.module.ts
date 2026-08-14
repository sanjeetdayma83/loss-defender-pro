import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { EvidenceService } from './evidence.service';
import { EvidenceController } from './evidence.controller';
import { StorageModule } from '../storage/storage.module';
import { FrameExtractorModule } from '../frame-extractor/frame-extractor.module';
import { QUEUE_FRAME_EXTRACTION } from '../frame-extractor/queue.constants';

@Module({
  imports: [StorageModule, FrameExtractorModule, BullModule.registerQueue({ name: QUEUE_FRAME_EXTRACTION })],
  controllers: [EvidenceController],
  providers: [EvidenceService],
  exports: [EvidenceService],
})
export class EvidenceModule {}
