import {
  Controller, Get, Post, Body, Param, Req,
} from '@nestjs/common';
import { RecordingsService } from './recordings.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { IsInt, IsOptional, IsString, IsUUID, Min } from 'class-validator';

class StartDto {
  @IsUUID() orderId: string;
  @IsUUID() warehouseId: string;
}
class StopDto {
  @IsOptional() @IsInt() @Min(0) durationSec?: number;
  @IsOptional() @IsInt() @Min(0) segmentCount?: number;
}
class PresignDto {
  @IsOptional() @IsInt() @Min(0) segmentIndex?: number;
  @IsOptional() @IsString() contentType?: string;
}
class RegisterSegmentDto {
  @IsInt() @Min(0) segmentIndex: number;
  @IsString() storageKey: string;
  @IsOptional() @IsString() checksum?: string;
  @IsOptional() @IsInt() sizeBytes?: number;
  @IsOptional() @IsInt() durationMs?: number;
}

@Controller('recordings')
export class RecordingsController {
  constructor(private readonly recordings: RecordingsService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.recordings.list(u.companyId);
  }

  @Post('start')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.packing_operator, Role.qc_operator, Role.super_admin)
  start(@CurrentUser() u: AuthenticatedUser, @Body() dto: StartDto) {
    return this.recordings.start(u.companyId, u.sub, dto.orderId, dto.warehouseId);
  }

  /** Flutter contract */
  @Post(':id/segments/presign')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.packing_operator, Role.qc_operator, Role.super_admin)
  presignSegmentPath(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: PresignDto,
  ) {
    return this.recordings.presignSegment(u.companyId, id, dto.segmentIndex ?? 0, dto.contentType);
  }

  /** Compat alias */
  @Post(':id/presign-segment')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.packing_operator, Role.qc_operator, Role.super_admin)
  presignSegmentAlias(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: PresignDto,
  ) {
    return this.recordings.presignSegment(u.companyId, id, dto.segmentIndex ?? 0, dto.contentType);
  }

  /** Register uploaded segment in DB */
  @Post(':id/segments')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.packing_operator, Role.qc_operator, Role.super_admin)
  registerSegment(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: RegisterSegmentDto,
  ) {
    return this.recordings.registerSegment(u.companyId, id, dto);
  }

  @Post(':id/stop')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.packing_operator, Role.qc_operator, Role.super_admin)
  stop(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: StopDto,
  ) {
    return this.recordings.stop(u.companyId, id, dto.durationSec, dto.segmentCount);
  }
}