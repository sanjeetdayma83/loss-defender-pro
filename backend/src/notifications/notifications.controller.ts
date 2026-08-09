import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { TenantGuard } from '../common/guards/tenant.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
@UseGuards(JwtAuthGuard, TenantGuard)
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.service.list(u.companyId, u.sub);
  }

  @Post()
  create(@CurrentUser() u: AuthenticatedUser, @Body() dto: CreateNotificationDto) {
    return this.service.create(u.companyId, dto);
  }

  @Patch(':id/read')
  markRead(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.service.markRead(u.companyId, id);
  }
}