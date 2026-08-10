import { Controller, Get } from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';

@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}
  @Get('kpis')
  kpis(@CurrentUser() u: AuthenticatedUser) {
    return this.analytics.kpis(u.companyId);
  }
}
