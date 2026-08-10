import { Controller, Get, Post, Body, BadRequestException } from '@nestjs/common';
import { StorageService } from './storage.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { IsString, IsOptional, IsInt, IsArray, ValidateNested, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';

class PresignDto {
  @IsString() purpose: string;
  @IsOptional() @IsString() filename?: string;
  @IsOptional() @IsString() contentType?: string;
}

class SignedDownloadDto {
  @IsString() key: string;
}

class InitMultipartDto {
  @IsString() purpose: string;
  @IsOptional() @IsString() filename?: string;
  @IsOptional() @IsString() contentType?: string;
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
  async presignUpload(@CurrentUser() u: AuthenticatedUser, @Body() dto: PresignDto) {
    const key = this.storage.buildKey(u.companyId, dto.purpose || 'misc', dto.filename);
    return this.storage.presignPut(key, dto.contentType || 'application/octet-stream');
  }

  @Post('presign-download')
  @ApiOperation({ summary: 'Tenant-scoped signed download URL (15 minute default TTL)' })
  async presignDownload(@CurrentUser() u: AuthenticatedUser, @Body() dto: SignedDownloadDto) {
    if (!dto.key.startsWith(`${u.companyId}/`)) {
      throw new BadRequestException('Invalid storage key for tenant');
    }
    return this.storage.presignGet(dto.key, 900);
  }

  @Post('multipart/init')
  @ApiOperation({ summary: 'Start resumable multipart upload' })
  async initMultipart(@CurrentUser() u: AuthenticatedUser, @Body() dto: InitMultipartDto) {
    const key = this.storage.buildKey(u.companyId, dto.purpose || 'misc', dto.filename);
    return this.storage.initMultipart(key, dto.contentType || 'application/octet-stream');
  }

  @Post('multipart/presign-part')
  @ApiOperation({ summary: 'Get presigned URL for one part' })
  async presignPart(@CurrentUser() u: AuthenticatedUser, @Body() dto: PresignPartDto) {
    if (!dto.key.startsWith(u.companyId + '/')) {
      return { configured: false, error: 'Invalid key for tenant' };
    }
    return this.storage.presignPart(dto.key, dto.uploadId, dto.partNumber);
  }

  @Post('multipart/complete')
  @ApiOperation({ summary: 'Complete multipart upload' })
  async completeMultipart(@CurrentUser() u: AuthenticatedUser, @Body() dto: CompleteMultipartDto) {
    if (!dto.key.startsWith(u.companyId + '/')) {
      return { configured: false, error: 'Invalid key for tenant' };
    }
    return this.storage.completeMultipart(dto.key, dto.uploadId, dto.parts);
  }

  @Post('multipart/abort')
  @ApiOperation({ summary: 'Abort multipart upload' })
  async abortMultipart(@CurrentUser() u: AuthenticatedUser, @Body() dto: AbortMultipartDto) {
    if (!dto.key.startsWith(u.companyId + '/')) {
      return { configured: false, error: 'Invalid key for tenant' };
    }
    return this.storage.abortMultipart(dto.key, dto.uploadId);
  }
}
