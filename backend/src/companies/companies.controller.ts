import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { CompaniesService } from './companies.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { TenantGuard } from '../common/guards/tenant.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';

@ApiTags('companies')
@ApiBearerAuth()
@Controller('companies')
@UseGuards(JwtAuthGuard, TenantGuard)
export class CompaniesController {
  constructor(private readonly service: CompaniesService) {}

  @Get('me')
  me(@CurrentUser() u: AuthenticatedUser) {
    return this.service.getMine(u.companyId);
  }

  @Get('me/export')
  @Roles(Role.owner, Role.super_admin)
  exportMe(@CurrentUser() u: AuthenticatedUser) {
    return this.service.exportCompanyData(u.companyId);
  }

  @Patch('me')
  @Roles(Role.owner, Role.manager, Role.super_admin)
  updateMe(
    @CurrentUser() u: AuthenticatedUser,
    @Body() dto: Record<string, unknown>,
    @Req() req: Request,
  ) {
    return this.service.updateMine(u.companyId, u.sub, dto as any, req.ip);
  }
}