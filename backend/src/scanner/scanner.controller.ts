import { Controller, Post, Body } from '@nestjs/common';
import { ScannerService } from './scanner.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { IsUUID, IsString, IsOptional } from 'class-validator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { RequirePlanLimit } from '../common/guards/plan-limit.guard';

class ScanDto {
  @IsUUID() orderId: string;
  @IsString() barcode: string;
  @IsOptional() @IsString() expectedSku?: string;
}

@ApiTags('scanner')
@ApiBearerAuth()
@Controller('scanner')
export class ScannerController {
  constructor(private readonly scanner: ScannerService) {}

  @RequirePlanLimit('scan')
  @Post('scan')
  scan(@CurrentUser() u: AuthenticatedUser, @Body() dto: ScanDto) {
    return this.scanner.scan(
      u.companyId, u.sub, dto.orderId, dto.barcode, dto.expectedSku,
    );
  }
}
