import { Controller, Get, Post, Body, BadRequestException } from '@nestjs/common';
import { StorageService } from './storage.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { IsString, IsOptional, IsInt, IsArray, ValidateNested, Min, IsIn } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';

const ALLOWED_CONTENT_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'video/mp4',
  'video/webm',
  'video/quicktime',
  'application/pdf',
  'application/octet-stream',
];

class PresignDto {
  @IsString() purpose: string;
  @IsOptional() @IsString() filename?: string;
  @IsOptional() @IsString() @IsIn(ALLOWED_CONTENT_TYPES) contentType?: string;
}

class InitMultipartDto {
  @IsString() purpose: string;
  @IsOptional() @IsString() filename?: string;
  @IsOptional() @IsString() @IsIn(ALLOWED_CONTENT_TYPES) contentType?: string;
}

class PresignPartDto {
  @IsString() key: string;
  @IsString() uploadId: string;
  @IsInt() @Min(1) partNumber: number;
}

class PartETag {
  @IsString() ETag: string;
  @IsInt() @Min(1) PartNumber: number;
}

class CompleteMultipartDto {
  @IsString() key: string;
  @IsString() uploadId: string;
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PartETag)
  parts: PartETag[];
}

class AbortMultipartDto {
  @IsString() key: string;
  @IsString() uploadId: string;
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
  async presignUpload(
    @CurrentUser() u: AuthenticatedUser,
    @Body() dto: PresignDto,
  ) {
    const contentType = dto.contentType || 'application/octet-stream';
    if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
      throw new BadRequestException(`Content type not allowed: ${contentType}`);
    }
    const key = this.storage.buildKey(u.companyId, dto.purpose || 'misc', dto.filename);
    return this.storage.presignPut(key, contentType);
  }

  @Post('multipart/init')
  @ApiOperation({ summary: 'Start resumable multipart upload' })
  async initMultipart(
    @CurrentUser() u: AuthenticatedUser,
    @Body() dto: InitMultipartDto,
  ) {
    const contentType = dto.contentType || 'application/octet-stream';
    if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
      throw new BadRequestException(`Content type not allowed: ${contentType}`);
    }
    const key = this.storage.buildKey(u.companyId, dto.purpose || 'misc', dto.filename);
    return this.storage.initMultipart(key, contentType);
  }

  @Post('multipart/presign-part')
  @ApiOperation({ summary: 'Get presigned URL for one part' })
  async presignPart(
    @CurrentUser() u: AuthenticatedUser,
    @Body() dto: PresignPartDto,
  ) {
    // key must belong to this tenant (starts with companyId/)
    if (!dto.key.startsWith(u.companyId + '/')) {
      return { configured: false, error: 'Invalid key for tenant' };
    }
    return this.storage.presignPart(dto.key, dto.uploadId, dto.partNumber);
  }

  @Post('multipart/complete')
  @ApiOperation({ summary: 'Complete multipart upload' })
  async completeMultipart(
    @CurrentUser() u: AuthenticatedUser,
    @Body() dto: CompleteMultipartDto,
  ) {
    if (!dto.key.startsWith(u.companyId + '/')) {
      return { configured: false, error: 'Invalid key for tenant' };
    }
    return this.storage.completeMultipart(dto.key, dto.uploadId, dto.parts);
  }

  @Post('multipart/abort')
  @ApiOperation({ summary: 'Abort multipart upload' })
  async abortMultipart(
    @CurrentUser() u: AuthenticatedUser,
    @Body() dto: AbortMultipartDto,
  ) {
    if (!dto.key.startsWith(u.companyId + '/')) {
      return { configured: false, error: 'Invalid key for tenant' };
    }
    return this.storage.abortMultipart(dto.key, dto.uploadId);
  }
}
