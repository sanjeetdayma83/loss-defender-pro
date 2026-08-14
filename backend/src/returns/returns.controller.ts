import { Controller, Get, Post, Patch, Body, Param } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { ReturnsService } from './returns.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { IsUUID, IsOptional, IsString } from 'class-validator';

class CreateReturnDto {
  @IsUUID() orderId: string;
  @IsOptional() @IsString() reason?: string;
  @IsOptional() @IsString() notes?: string;
}
class UpdateReturnDto {
  @IsString() status: string;
}

@Controller('returns')
export class ReturnsController {
  constructor(private readonly returns: ReturnsService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.returns.list(u.companyId, u);
  }

  @Post()
  @Roles(Role.owner, Role.manager, Role.claims_executive, Role.supervisor, Role.super_admin)
  create(@CurrentUser() u: AuthenticatedUser, @Body() dto: CreateReturnDto) {
    return this.returns.create(u.companyId, dto, u);
  }

  @Patch(':id')
  @Roles(Role.owner, Role.manager, Role.claims_executive, Role.super_admin)
  update(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateReturnDto) {
    return this.returns.updateStatus(u.companyId, id, dto.status, u);
  }
}