import { Controller, Get, Param } from '@nestjs/common';
import { EvidenceService } from './evidence.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('evidence')
@ApiBearerAuth()
@Controller('evidence')
export class EvidenceController {
  constructor(private readonly evidence: EvidenceService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.evidence.list(u.companyId);
  }

  @Get(':id')
  getOne(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.evidence.getOne(u.companyId, id);
  }
}
