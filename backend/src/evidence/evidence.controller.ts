import { Controller, Get, Post, Param, Body } from '@nestjs/common';
import { EvidenceService } from './evidence.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { IsString } from 'class-validator';

class ExtractFramesDto {
  @IsString() videoPath: string;
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

  @Get(':id')
  getOne(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.evidence.getOne(u.companyId, id);
  }

  @Post(':id/extract-frames')
  extractFrames(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: ExtractFramesDto,
  ) {
    return this.evidence.processLocalVideo(u.companyId, id, body.videoPath);
  }
}
