import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { RecordingsService } from './recordings.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { IsUUID, IsOptional, IsNumber, IsString } from 'class-validator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { Type } from 'class-transformer';
class StartRecordingDto { @IsUUID() orderId: string; @IsUUID() warehouseId: string; }
class StopRecordingDto { @IsOptional() @Type(() => Number) @IsNumber() durationSec?: number; @IsOptional() @Type(() => Number) @IsNumber() segmentCount?: number; }
class PresignSegmentDto { @Type(() => Number) @IsNumber() segmentIndex: number; @IsOptional() @IsString() contentType?: string; }
class RegisterSegmentDto { @Type(() => Number) @IsNumber() sequence: number; @IsString() b2Key: string; @IsOptional() @Type(() => Number) @IsNumber() sizeBytes?: number; @IsOptional() @Type(() => Number) @IsNumber() durationSec?: number; }
@ApiTags('recordings') @ApiBearerAuth() @Controller('recordings')
export class RecordingsController {
  constructor(private readonly recordings: RecordingsService) {}
  @Get() list(@CurrentUser() u: AuthenticatedUser) { return this.recordings.list(u.companyId); }
  @Get(':id') getOne(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) { return this.recordings.getOne(u.companyId, id); }
  @Post('start') start(@CurrentUser() u: AuthenticatedUser, @Body() dto: StartRecordingDto) { return this.recordings.start(u.companyId, u.sub, dto.orderId, dto.warehouseId); }
  @Post(':id/stop') stop(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string, @Body() dto: StopRecordingDto) { return this.recordings.stop(u.companyId, id, u.sub, dto.durationSec, dto.segmentCount); }
  @Post(':id/segments/presign') presignSegment(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string, @Body() dto: PresignSegmentDto) { return this.recordings.presignSegment(u.companyId, id, dto.segmentIndex, dto.contentType || 'video/webm'); }
  @Post(':id/presign-segment') presignLegacy(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string, @Body() dto: PresignSegmentDto) { return this.recordings.presignSegment(u.companyId, id, dto.segmentIndex, dto.contentType || 'video/webm'); }
  @Post(':id/segments') registerSegment(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string, @Body() dto: RegisterSegmentDto) { return this.recordings.registerSegment(u.companyId, id, dto.sequence, dto.b2Key, dto.sizeBytes, dto.durationSec); }

  @Get(':id/segments')
  listSegments(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.recordings.listSegments(u.companyId, id);
  }

  @Get(':id/segments/:sequence/url')
  segmentUrl(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string, @Param('sequence') sequence: string) {
    return this.recordings.segmentDownloadUrl(u.companyId, id, Number(sequence));
  }
}