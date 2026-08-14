import { Module } from '@nestjs/common';
import { FrameExtractorService } from './frame-extractor.service';
import { FrameExtractorWorker } from './frame-extractor.worker';
import { BullModule } from '@nestjs/bullmq';
import { QUEUE_FRAME_EXTRACTION } from './queue.constants';

@Module({
  imports: [
    BullModule.registerQueue({
      name: QUEUE_FRAME_EXTRACTION,
    }),
  ],
  providers: [FrameExtractorService, FrameExtractorWorker],
  exports: [FrameExtractorService, FrameExtractorWorker],
})
export class FrameExtractorModule {}