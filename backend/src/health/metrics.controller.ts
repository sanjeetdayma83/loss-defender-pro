import { Controller, Get } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';

@Controller('metrics')
export class MetricsController {
  private static startedAt = Date.now();
  private static requests = 0;

  static hit() {
    MetricsController.requests++;
  }

  @Public()
  @Get()
  get() {
    const mem = process.memoryUsage();
    return {
      uptimeSec: Math.floor((Date.now() - MetricsController.startedAt) / 1000),
      requests: MetricsController.requests,
      memory: {
        rss: mem.rss,
        heapUsed: mem.heapUsed,
      },
      node: process.version,
      env: process.env.NODE_ENV || 'development',
    };
  }
}
