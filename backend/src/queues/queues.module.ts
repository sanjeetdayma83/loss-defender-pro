import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { EmailModule } from '../email/email.module';
import { EvidenceModule } from '../evidence/evidence.module';
import { PrismaModule } from '../prisma/prisma.module';
import { EmailProcessor } from './email.processor';
import { EvidenceProcessor } from './evidence.processor';
import { NotificationProcessor } from './notification.processor';
import { QUEUE_EMAIL, QUEUE_EVIDENCE, QUEUE_NOTIFICATION } from './queue.constants';

export { QUEUE_EMAIL, QUEUE_EVIDENCE, QUEUE_NOTIFICATION } from './queue.constants';

@Module({
  imports: [
    PrismaModule,
    EmailModule,
    EvidenceModule,
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const password = config.get<string>('REDIS_PASSWORD');
        return {
          connection: {
            host: config.get<string>('REDIS_HOST') || '127.0.0.1',
            port: parseInt(config.get<string>('REDIS_PORT') || '6379', 10),
            ...(password ? { password } : {}),
          },
        };
      },
    }),
    BullModule.registerQueue(
      { name: QUEUE_EMAIL },
      { name: QUEUE_EVIDENCE },
      { name: QUEUE_NOTIFICATION },
    ),
  ],
  providers: [EmailProcessor, EvidenceProcessor, NotificationProcessor],
  exports: [BullModule],
})
export class QueuesModule {}
