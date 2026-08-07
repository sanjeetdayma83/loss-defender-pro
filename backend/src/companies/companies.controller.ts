import { Controller, Get, Patch, Body, Req } from '@nestjs/common';
import { CompaniesService } from './companies.service';
import { UpdateCompanyDto } from './dto/update-company.dto';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { Request } from 'express';

@Controller('companies')
export class CompaniesController {
  constructor(private readonly companies: CompaniesService) {}

  /** GET /api/v1/companies/me — current tenant profile */
  @Get('me')
  getMine(@CurrentUser() user: AuthenticatedUser) {
    return this.companies.getMine(user.companyId);
  }

  /** PATCH /api/v1/companies/me — owner/manager only */
  @Patch('me')
  @Roles(Role.owner, Role.manager, Role.super_admin)
  updateMine(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateCompanyDto,
    @Req() req: Request,
  ) {
    return this.companies.updateMine(
      user.companyId,
      user.sub,
      dto,
      req.ip,
    );
  }
}
