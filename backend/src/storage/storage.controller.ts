import { Controller, Get, Post, Body } from '@nestjs/common';
import { StorageService } from './storage.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { IsString, IsOptional } from 'class-validator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

class PresignDto {
  @IsString() purpose: string;
  @IsOptional() @IsString() filename?: string;
  @IsOptional() @IsString() contentType?: string;
}

@ApiTags('storage')
@ApiBearerAuth()
@Controller('storage')
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  @Get('status')
  status() {
    return { configured: this.storage.isConfigured() };
  }

  @Post('presign-upload')
  async presignUpload(
    @CurrentUser() u: AuthenticatedUser,
    @Body() dto: PresignDto,
  ) {
    const key = this.storage.buildKey(u.companyId, dto.purpose || 'misc', dto.filename);
    return this.storage.presignPut(key, dto.contentType || 'application/octet-stream');
  }
}
