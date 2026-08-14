import { Controller, Get, Post, Param, Body } from '@nestjs/common';
import { EvidenceService } from './evidence.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { IsString, IsOptional, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

class ProcessEvidenceDto {
  @IsString() recordingId: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(30)
  maxFramesPerSegment?: number;
}

@ApiTags('evidence')
@ApiBearerAuth()
@Controller('evidence')
export class EvidenceController {
  constructor(private readonly evidence: EvidenceService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.evidence.list(u.companyId);
  }

  @Get(':id/download-url')
  downloadUrl(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.evidence.getDownloadUrl(u.companyId, id);
  }

  
  @Get(':id/frames/:frameId/url')
  frameUrl(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Param('frameId') frameId: string,
  ) {
    return this.evidence.getFrameUrl(u.companyId, id, frameId);
  }
  @Get(':id')
  getOne(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.evidence.getOne(u.companyId, id);
  }

  /** Process frames from B2-registered recording segments (production path). */
  @Post(':id/process')
  process(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: ProcessEvidenceDto,
  ) {
    return this.evidence.processRecordingEvidence(
      u.companyId,
      body.recordingId,
      id,
      body.maxFramesPerSegment ?? 8,
    );
  }
}
