import { Controller, Get, Post, Param, Body } from '@nestjs/common';
import { EvidenceService } from './evidence.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { IsString } from 'class-validator';
import { RequirePermission } from '../common/guards/permissions.guard';

class ExtractFramesDto {
  @IsString() videoPath: string;
}

@ApiTags('evidence')
@ApiBearerAuth()
@Controller('evidence')
export class EvidenceController {
  constructor(private readonly evidence: EvidenceService) {}

  @Get()
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.claims_executive, Role.super_admin)
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.evidence.list(u.companyId, u);
  }

  @Get(':id/download')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.claims_executive, Role.super_admin)
  download(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.evidence.getDownload(u.companyId, id, u);
  }

  @Get(':id')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.claims_executive, Role.super_admin)
  getOne(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.evidence.getOne(u.companyId, id, u);
  }

  @RequirePermission('evidence.export')
  @Post(':id/extract-frames')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.super_admin)
  extractFrames(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: ExtractFramesDto,
  ) {
    return this.evidence.processLocalVideo(u.companyId, id, body.videoPath, u);
  }
}