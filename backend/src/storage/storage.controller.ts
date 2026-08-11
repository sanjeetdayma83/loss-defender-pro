import { Controller, Get, Post, Body, BadRequestException } from '@nestjs/common';
import { StorageService } from './storage.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import {
  IsString, IsOptional, IsInt, IsArray, ValidateNested, Min, Max, IsIn,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';

const ALLOWED_PURPOSES = ['recordings', 'evidence', 'misc', 'claims', 'returns'] as const;
const ALLOWED_CONTENT_TYPES = [
  'video/webm', 'video/mp4', 'image/jpeg', 'image/png', 'image/webp',
  'application/json', 'application/octet-stream',
] as const;
const MAX_SINGLE_UPLOAD_BYTES = 100 * 1024 * 1024;
const MAX_PART_BYTES = 50 * 1024 * 1024;

class PresignDto {
  @IsIn(ALLOWED_PURPOSES as unknown as string[]) purpose: string;
  @IsOptional() @IsString() filename?: string;
  @IsOptional() @IsIn(ALLOWED_CONTENT_TYPES as unknown as string[]) contentType?: string;
  @IsOptional() @IsInt() @Min(1) @Max(MAX_SINGLE_UPLOAD_BYTES) contentLength?: number;
}
class InitMultipartDto {
  @IsIn(ALLOWED_PURPOSES as unknown as string[]) purpose: string;
  @IsOptional() @IsString() filename?: string;
  @IsOptional() @IsIn(ALLOWED_CONTENT_TYPES as unknown as string[]) contentType?: string;
  @IsOptional() @IsInt() @Min(1) @Max(5 * 1024 * 1024 * 1024) totalSize?: number;
}
class PresignPartDto {
  @IsString() key: string;
  @IsString() uploadId: string;
  @IsInt() @Min(1) partNumber: number;
  @IsOptional() @IsInt() @Min(1) @Max(MAX_PART_BYTES) contentLength?: number;
}
class PartETag {
  @IsString() ETag: string;
  @IsInt() @Min(1) PartNumber: number;
}
class CompleteMultipartDto {
  @IsString() key: string;
  @IsString() uploadId: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => PartETag) parts: PartETag[];
}
class AbortMultipartDto {
  @IsString() key: string;
  @IsString() uploadId: string;
}
class PresignDownloadDto {
  @IsString() key: string;
}

@ApiTags('storage')
@ApiBearerAuth()
@Controller('storage')
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  @Get('status')
  @ApiOperation({ summary: 'Check if B2 storage is configured' })
  status() {
    return { configured: this.storage.isConfigured() };
  }

  @Post('presign-upload')
  @ApiOperation({ summary: 'Simple single-part presigned PUT' })
  async presignUpload(@CurrentUser() u: AuthenticatedUser, @Body() dto: PresignDto) {
    if (dto.filename && /[\\/]|\.\./.test(dto.filename)) {
      throw new BadRequestException('Invalid filename');
    }
    const key = this.storage.buildKey(u.companyId, dto.purpose, dto.filename);
    return this.storage.presignPut(key, dto.contentType || 'application/octet-stream');
  }

  @Post('presign-download')
  @ApiOperation({ summary: 'Presigned GET download/playback' })
  async presignDownload(@CurrentUser() u: AuthenticatedUser, @Body() dto: PresignDownloadDto) {
    if (!dto?.key) throw new BadRequestException('key required');
    if (!dto.key.startsWith(u.companyId + '/')) {
      throw new BadRequestException('Invalid key for tenant');
    }
    return this.storage.presignGet(dto.key);
  }

  @Post('multipart/init')
  async initMultipart(@CurrentUser() u: AuthenticatedUser, @Body() dto: InitMultipartDto) {
    if (dto.filename && /[\\/]|\.\./.test(dto.filename)) {
      throw new BadRequestException('Invalid filename');
    }
    const key = this.storage.buildKey(u.companyId, dto.purpose, dto.filename);
    return this.storage.initMultipart(key, dto.contentType || 'application/octet-stream');
  }

  @Post('multipart/presign-part')
  async presignPart(@CurrentUser() u: AuthenticatedUser, @Body() dto: PresignPartDto) {
    if (!dto.key.startsWith(u.companyId + '/')) throw new BadRequestException('Invalid key for tenant');
    return this.storage.presignPart(dto.key, dto.uploadId, dto.partNumber);
  }

  @Post('multipart/complete')
  async completeMultipart(@CurrentUser() u: AuthenticatedUser, @Body() dto: CompleteMultipartDto) {
    if (!dto.key.startsWith(u.companyId + '/')) throw new BadRequestException('Invalid key for tenant');
    return this.storage.completeMultipart(dto.key, dto.uploadId, dto.parts);
  }

  @Post('multipart/abort')
  async abortMultipart(@CurrentUser() u: AuthenticatedUser, @Body() dto: AbortMultipartDto) {
    if (!dto.key.startsWith(u.companyId + '/')) throw new BadRequestException('Invalid key for tenant');
    return this.storage.abortMultipart(dto.key, dto.uploadId);
  }
}
