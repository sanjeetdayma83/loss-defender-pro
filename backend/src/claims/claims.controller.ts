import { Controller, Get, Post, Patch, Body, Param } from '@nestjs/common';
import { ClaimsService } from './claims.service';
import {
  CurrentUser,
  AuthenticatedUser,
} from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { CreateClaimDto } from './dto/create-claim.dto';
import { IsString, IsOptional } from 'class-validator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

class UpdateClaimDto {
  @IsString() status: string;
  @IsOptional() @IsString() decisionNote?: string;
}

@ApiTags('claims')
@ApiBearerAuth()
@Controller('claims')
export class ClaimsController {
  constructor(private readonly claims: ClaimsService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.claims.list(u.companyId);
  }

  @Get(':id')
  getOne(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.claims.getOne(u.companyId, id);
  }

  @Post()
  @Roles(
    Role.owner,
    Role.manager,
    Role.claims_executive,
    Role.super_admin,
  )
  create(@CurrentUser() u: AuthenticatedUser, @Body() dto: CreateClaimDto) {
    const actorId = (u as any).id || (u as any).sub || (u as any).userId;
    return this.claims.create(u.companyId, actorId, dto);
  }

  @Patch(':id')
  @Roles(
    Role.owner,
    Role.manager,
    Role.claims_executive,
    Role.super_admin,
  )
  update(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateClaimDto,
  ) {
    const actorId = (u as any).id || (u as any).sub || (u as any).userId;
    return this.claims.updateStatus(
      u.companyId,
      actorId,
      id,
      dto.status,
      dto.decisionNote,
    );
  }
}