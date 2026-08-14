import { GoogleOAuthService } from './oauth/google-oauth.service';
import { Controller, Post, Get, Delete, Body, Param, Req , Query } from '@nestjs/common';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { RegisterDto, LoginDto, ForgotPasswordDto, ResetPasswordDto, VerifyEmailDto, RefreshDto, LogoutDto } from './dto/auth.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { AcceptInviteDto } from './dto/accept-invite.dto';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Request } from 'express';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService, private readonly otp: OtpService, private readonly google: GoogleOAuthService) {}

  @Public() @Throttle({ default: { limit: 5, ttl: 60000 } }) @Post('register') @ApiOperation({ summary: 'Register company + owner' })
  register(@Body() dto: RegisterDto, @Req() req: Request) { return this.auth.register(dto, req.ip); }

  @Public() @Throttle({ default: { limit: 5, ttl: 60000 } }) @Post('login')
  login(@Body() dto: LoginDto, @Req() req: Request) { return this.auth.login(dto, req.ip, req.headers['user-agent']); }

  @Public() @Throttle({ default: { limit: 20, ttl: 60000 } }) @Post('refresh')
  refresh(@Body() dto: RefreshDto, @Req() req: Request) { return this.auth.refresh(dto, req.ip, req.headers['user-agent']); }

  @Post('logout') @ApiBearerAuth()
  logout(@CurrentUser() u: AuthenticatedUser, @Body() dto: LogoutDto, @Req() req: Request) {
    const h = req.headers.authorization || '';
    return this.auth.logout(u.sub, dto, h.startsWith('Bearer ') ? h.slice(7) : undefined);
  }

  @Public() @Throttle({ default: { limit: 5, ttl: 60000 } }) @Post('forgot-password')
  forgot(@Body() dto: ForgotPasswordDto) { return this.auth.forgotPassword(dto); }

  @Public() @Throttle({ default: { limit: 5, ttl: 60000 } }) @Post('reset-password')
  reset(@Body() dto: ResetPasswordDto) { return this.auth.resetPassword(dto); }

  @Public() @Throttle({ default: { limit: 5, ttl: 60000 } }) @Post('verify-email')
  verify(@Body() dto: VerifyEmailDto) { return this.auth.verifyEmail(dto); }

  @Post('change-password') @ApiBearerAuth()
  changePassword(@CurrentUser() u: AuthenticatedUser, @Body() dto: ChangePasswordDto) { return this.auth.changePassword(u.sub, dto.currentPassword, dto.newPassword, dto.otpCode); }

  @Public() @Throttle({ default: { limit: 5, ttl: 60000 } }) @Post('accept-invite')
  acceptInvite(@Body() dto: AcceptInviteDto) { return this.auth.acceptInvite(dto); }

  @Get('sessions') @ApiBearerAuth()
  sessions(@CurrentUser() u: AuthenticatedUser) { return this.auth.sessions(u.sub); }

  @Delete('sessions/:id') @ApiBearerAuth()
  revoke(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) { return this.auth.revokeSession(u.sub, id); }

  @Post('logout-all') logoutAll(@CurrentUser() u: AuthenticatedUser) { return this.auth.logoutAll(u.sub); }

  @Public() @Throttle({ default: { limit: 5, ttl: 60000 } }) @Post('otp/request')
  otpRequest(@Body() b: { email: string; purpose?: string }) { return this.otp.request(b.email, b.purpose || 'sensitive'); }

  @Public() @Throttle({ default: { limit: 10, ttl: 60000 } }) @Post('otp/verify')
  otpVerify(@Body() b: { email: string; purpose?: string; code: string }) { return this.otp.verify(b.email, b.purpose || 'sensitive', b.code); }

  @Public() @Get('google/start') googleStart() { return this.google.getStartUrl(); }


  @Public()
  @Get('google/callback')
  googleCallback(@Query('code') code: string) {
    return this.google.handleCallback(code);
  }
}
