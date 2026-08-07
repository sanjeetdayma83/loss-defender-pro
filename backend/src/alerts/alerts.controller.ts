import { Controller, Get } from '@nestjs/common';
import { AlertsService } from './alerts.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('alerts')
@ApiBearerAuth()
@Controller('alerts')
export class AlertsController {
  constructor(private readonly alerts: AlertsService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.alerts.list(u.companyId);
  }
}
