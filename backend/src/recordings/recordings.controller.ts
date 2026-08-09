import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { RecordingsService } from './recordings.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { IsUUID, IsOptional, IsInt, IsString, Min } from 'class-validator';

class StartDto {
  @IsUUID() orderId: string;
  @IsUUID() warehouseId: string;
}
class StopDto {
  @IsOptional() @IsInt() durationSec?: number;
  @IsOptional() @IsInt() segmentCount?: number;
}
class PresignDto {
  @IsOptional() @IsInt() segmentIndex?: number;
  @IsOptional() @IsString() contentType?: string;
}
class AddSegmentDto {
  @IsInt() @Min(0) sequence: number;
  @IsString() b2Key: string;
  @IsInt() @Min(0) sizeBytes: number;
  @IsOptional() @IsInt() durationSec?: number;
  @IsOptional() @IsString() checksum?: string;
}

@Controller('recordings')
export class RecordingsController {
  constructor(private readonly recordings: RecordingsService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.recordings.list(u.companyId);
  }

  @Post('start')
  start(@CurrentUser() u: AuthenticatedUser, @Body() dto: StartDto) {
    return this.recordings.start(
      u.companyId,
      u.sub,
      dto.orderId,
      dto.warehouseId,
    );
  }

  @Post(':id/stop')
  stop(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: StopDto,
  ) {
    return this.recordings.stop(
      u.companyId,
      id,
      dto.durationSec,
      dto.segmentCount,
    );
  }

  @Post(':id/segments/presign')
  presign(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: PresignDto,
  ) {
    return this.recordings.presignSegment(
      u.companyId,
      id,
      dto.segmentIndex ?? 0,
      dto.contentType,
    );
  }

  @Post(':id/segments')
  addSegment(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AddSegmentDto,
  ) {
    return this.recordings.addSegment(u.companyId, id, dto);
  }
}