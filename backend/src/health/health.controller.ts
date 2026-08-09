import { Controller, Get } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@Controller()
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  @Public()
  @Get('health')
  health() {
    return {
      status: 'ok',
      service: 'loss-defender-pro',
      ts: new Date().toISOString(),
    };
  }

  @Public()
  @Get('ready')
  async ready() {
    let database = false;
    let redis = false;

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      database = true;
    } catch {
      database = false;
    }

    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const Redis = require('ioredis');
      const client = new Redis({
        host: process.env.REDIS_HOST || '127.0.0.1',
        port: Number(process.env.REDIS_PORT || 6379),
        maxRetriesPerRequest: 1,
        connectTimeout: 2000,
        lazyConnect: true,
      });
      await client.connect();
      redis = (await client.ping()) === 'PONG';
      await client.quit();
    } catch {
      redis = false;
    }

    const storage = this.storage.isConfigured?.() ?? false;
    const status = !database ? 'not_ready' : redis ? 'ready' : 'degraded';

    return {
      status,
      checks: { database, redis, storage },
      ts: new Date().toISOString(),
    };
  }
}
