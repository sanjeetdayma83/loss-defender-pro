import { SupervisorController } from './supervisor.controller';
import { Global, Module } from '@nestjs/common';
import { EventsGateway } from './events.gateway';

@Global()
@Module({
  controllers: [SupervisorController],
  providers: [EventsGateway],
  exports: [EventsGateway],
})
export class RealtimeModule {}