import { GoogleOAuthService } from './oauth/google-oauth.service';
import {
  Controller, Post, Get, Delete, Body, Param, Req,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import {
  RegisterDto, LoginDto, ForgotPasswordDto, ResetPasswordDto,
  VerifyEmailDto, RefreshDto, LogoutDto,
} from './dto/auth.dto';
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

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post('register')
  @ApiOperation({ summary: 'Register company + owner' })
  register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.auth.register(dto, req.ip);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('login')
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(dto, req.ip, req.headers['user-agent']);
  }

  @Public()
  @Post('refresh')
  refresh(@Body() dto: RefreshDto, @Req() req: Request) {
    return this.auth.refresh(dto, req.ip, req.headers['user-agent']);
  }

  @Post('logout')
  @ApiBearerAuth()
  logout(@CurrentUser() user: AuthenticatedUser, @Body() dto: LogoutDto) {
    return this.auth.logout(user.sub, dto);
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post('forgot-password')
  forgot(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto);
  }

  @Public()
  @Post('reset-password')
  reset(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto);
  }

  @Public()
  @Post('verify-email')
  verify(@Body() dto: VerifyEmailDto) {
    return this.auth.verifyEmail(dto);
  }

  @Post('change-password')
  @ApiBearerAuth()
  changePassword(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.auth.changePassword(user.sub, dto.currentPassword, dto.newPassword);
  }

  @Public()
  @Post('accept-invite')
  acceptInvite(@Body() dto: AcceptInviteDto) {
    return this.auth.acceptInvite(dto);
  }

  @Get('sessions')
  @ApiBearerAuth()
  sessions(@CurrentUser() user: AuthenticatedUser) {
    return this.auth.sessions(user.sub);
  }

  @Delete('sessions/:id')
  @ApiBearerAuth()
  revoke(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.auth.revokeSession(user.sub, id);
  }
  @Post('logout-all')
  logoutAll(@CurrentUser() user: AuthenticatedUser) {
    return this.auth.revokeAllSessions(user.sub);
  }

  @Public()
  @Post('otp/request')
  otpRequest(@Body() body: { email: string; purpose?: string }) {
    return this.otp.request(body.email, body.purpose || 'sensitive');
  }

  @Public()
  @Post('otp/verify')
  otpVerify(@Body() body: { email: string; purpose?: string; code: string }) {
    return this.otp.verify(body.email, body.purpose || 'sensitive', body.code);
  }

  @Public()
  @Get('google/start')
  googleStart() {
    return this.google.getStartUrl();
  }

  @Public()
  @Get('oauth/providers')
  oauthProviders() {
    return {
      google: Boolean(process.env.GOOGLE_CLIENT_ID),
      microsoft: Boolean(process.env.MICROSOFT_CLIENT_ID),
    };
  }
}
