import { IsEmail, IsString, MinLength, MaxLength, IsOptional } from 'class-validator';

export class RegisterDto {
  @IsEmail() email: string;
  @IsString() @MinLength(6) @MaxLength(72) password: string;
  @IsString() @MinLength(2) @MaxLength(120) name: string;
  @IsString() @MinLength(2) @MaxLength(200) companyName: string;
  @IsOptional() @IsString() @MaxLength(20) phone?: string;
}

export class LoginDto {
  @IsEmail() email: string;
  @IsString() password: string;
  @IsOptional() @IsString() deviceId?: string;
}

export class ForgotPasswordDto {
  @IsEmail() email: string;
}

export class ResetPasswordDto {
  @IsEmail() email: string;
  @IsString() @MinLength(4) @MaxLength(8) code: string;
  @IsString() @MinLength(6) @MaxLength(72) newPassword: string;
}

export class VerifyEmailDto {
  @IsEmail() email: string;
  @IsString() @MinLength(4) @MaxLength(8) code: string;
}

export class RefreshDto {
  @IsString() refreshToken: string;
  @IsOptional() @IsString() deviceId?: string;
}

export class LogoutDto {
  @IsOptional() @IsString() refreshToken?: string;
  @IsOptional() @IsString() deviceId?: string;
}
