import { IsString, IsOptional, IsIn } from 'class-validator';

export class UpdateReturnDto {
  @IsOptional()
  @IsIn(['requested', 'received', 'inspecting', 'refunded', 'restocked', 'rejected', 'closed'])
  status?: string;

  @IsOptional()
  @IsString()
  conditionNote?: string;

  @IsOptional()
  @IsString()
  decision?: string;
}