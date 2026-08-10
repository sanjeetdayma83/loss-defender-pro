import {
  Controller, Get, Post, Body, Param,
} from '@nestjs/common';
import { RecordingsService } from './recordings.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { IsUUID, IsOptional, IsNumber, IsString } from 'class-validator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { Type } from 'class-transformer';

class StartRecordingDto {
  @IsUUID() orderId: string;
  @IsUUID() warehouseId: string;
}

class StopRecordingDto {
  @IsOptional() @Type(() => Number) @IsNumber() durationSec?: number;
  @IsOptional() @Type(() => Number) @IsNumber() segmentCount?: number;
}

class PresignSegmentDto {
  @Type(() => Number) @IsNumber() segmentIndex: number;
  @IsOptional() @IsString() contentType?: string;
}

@ApiTags('recordings')
@ApiBearerAuth()
@Controller('recordings')
export class RecordingsController {
  constructor(private readonly recordings: RecordingsService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.recordings.list(u.companyId);
  }

  @Get(':id')
  getOne(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.recordings.getOne(u.companyId, id);
  }

  @Post('start')
  start(@CurrentUser() u: AuthenticatedUser, @Body() dto: StartRecordingDto) {
    const actorId = (u as any).id || (u as any).sub || (u as any).userId;
    return this.recordings.start(u.companyId, actorId, dto.orderId, dto.warehouseId);
  }

  @Post(':id/stop')
  stop(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: StopRecordingDto,
  ) {
    const actorId = (u as any).id || (u as any).sub || (u as any).userId;
    return this.recordings.stop(u.companyId, id, actorId, dto.durationSec, dto.segmentCount);
  }

  @Post(':id/presign-segment')
  presignSegment(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: PresignSegmentDto,
  ) {
    return this.recordings.presignSegment(
      u.companyId,
      id,
      dto.segmentIndex,
      dto.contentType || 'video/webm',
    );
  }
}
