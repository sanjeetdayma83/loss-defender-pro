import { Controller, Get, Post, Body, Param } from '@nestjs/common';
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
  @IsOptional() @Type(() => Number) @IsNumber() segmentIndex?: number;
  @IsOptional() @Type(() => Number) @IsNumber() sequence?: number;
  @IsOptional() @IsString() contentType?: string;
}

class RegisterSegmentDto {
  @Type(() => Number) @IsNumber() sequence: number;
  @IsString() b2Key: string;
  @IsOptional() @Type(() => Number) @IsNumber() sizeBytes?: number;
  @IsOptional() @Type(() => Number) @IsNumber() durationSec?: number;
  @IsOptional() @IsString() checksum?: string;
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

  @Get(':id/download')
  download(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.recordings.getDownload(u.companyId, id);
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
    return this.recordings.stop(u.companyId, id, dto.durationSec, dto.segmentCount);
  }

  /** Canonical + Flutter-compatible alias */
  @Post(':id/presign-segment')
  presignSegment(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: PresignSegmentDto,
  ) {
    const idx = dto.segmentIndex ?? dto.sequence ?? 0;
    return this.recordings.presignSegment(
      u.companyId,
      id,
      idx,
      dto.contentType || 'video/webm',
    );
  }

  /** Flutter path: POST /recordings/:id/segments/presign */
  @Post(':id/segments/presign')
  presignSegmentAlias(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: PresignSegmentDto,
  ) {
    const idx = dto.segmentIndex ?? dto.sequence ?? 0;
    return this.recordings.presignSegment(
      u.companyId,
      id,
      idx,
      dto.contentType || 'video/webm',
    );
  }

  /** Flutter path: POST /recordings/:id/segments */
  @Post(':id/segments')
  registerSegment(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: RegisterSegmentDto,
  ) {
    return this.recordings.addSegment(u.companyId, id, {
      sequence: dto.sequence,
      b2Key: dto.b2Key,
      sizeBytes: dto.sizeBytes ?? 0,
      durationSec: dto.durationSec ?? 0,
      checksum: dto.checksum,
    });
  }
}