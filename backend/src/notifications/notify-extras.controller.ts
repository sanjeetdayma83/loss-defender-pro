import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';

@Controller('notifications')
export class NotifyExtrasController {
  @UseGuards(JwtAuthGuard)
  @Post('sms/test')
  sms(@CurrentUser() u: AuthenticatedUser, @Body() body: { to: string; message: string }) {
    const key = process.env.SMS_API_KEY || '';
    return {
      queued: false,
      configured: !!(key && !key.includes('PLACE')),
      to: body.to,
      message: 'Set SMS_API_KEY (MSG91/Twilio) — PLACE_YOUR_KEY',
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('whatsapp/test')
  wa(@CurrentUser() u: AuthenticatedUser, @Body() body: { to: string; message: string }) {
    const key = process.env.WHATSAPP_TOKEN || '';
    return {
      queued: false,
      configured: !!(key && !key.includes('PLACE')),
      to: body.to,
      message: 'Set WHATSAPP_TOKEN — PLACE_YOUR_KEY',
    };
  }
}
