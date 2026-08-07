import { IsString, IsOptional, IsIn } from 'class-validator';

export class UpdateClaimDto {
  @IsOptional()
  @IsIn(['open', 'investigating', 'approved', 'rejected', 'escalated', 'closed'])
  status?: string;

  @IsOptional()
  @IsString()
  decisionNote?: string;
}