import { IsEnum, IsOptional, IsString, IsUUID, MinLength } from 'class-validator';

export enum ChannelDto {
  in_app = 'in_app',
  email = 'email',
  sms = 'sms',
  push = 'push',
  whatsapp = 'whatsapp',
}

export class CreateNotificationDto {
  @IsOptional() @IsUUID()
  userId?: string;

  @IsEnum(ChannelDto)
  channel: ChannelDto;

  @IsString() @MinLength(1)
  title: string;

  @IsString() @MinLength(1)
  body: string;

  @IsOptional()
  data?: Record<string, unknown>;
}