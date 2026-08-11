import { SupervisorController } from './supervisor.controller';
import { Global, Module } from '@nestjs/common';
import { EventsGateway } from './events.gateway';
import { AuthModule } from '../auth/auth.module';

@Global()
@Module({
  imports: [AuthModule],
  controllers: [SupervisorController],
  providers: [EventsGateway],
  exports: [EventsGateway],
})
export class RealtimeModule {}
