import { Controller, Get, Patch, Body, Param } from '@nestjs/common';
import { ClaimsService } from './claims.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
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

  @Patch(':id')
  update(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateClaimDto,
  ) {
    const actorId = (u as any).id || (u as any).sub || (u as any).userId;
    return this.claims.updateStatus(u.companyId, actorId, id, dto.status, dto.decisionNote);
  }
}
