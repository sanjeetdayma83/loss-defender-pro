import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';

export const SUPPORT_CONTACTS = {
  supportEmail: 'support@lossdefender.in',
  infoEmail: 'info@lossdefender.in',
  whatsapp: '8278124406',
  whatsappUrl: 'https://wa.me/918278124406',
  company: 'Loss Defender Pro',
  hours: 'Mon–Sat 10:00–19:00 IST',
};

@Controller('support')
export class SupportController {
  @Public()
  @Get('contacts')
  contacts() {
    return SUPPORT_CONTACTS;
  }

  @UseGuards(JwtAuthGuard)
  @Post('ticket')
  ticket(
    @CurrentUser() u: AuthenticatedUser,
    @Body() body: { subject?: string; message?: string; category?: string },
  ) {
    const payload = {
      companyId: u.companyId,
      userId: u.sub,
      subject: (body.subject || 'Support request').slice(0, 200),
      message: (body.message || '').slice(0, 4000),
      category: body.category || 'general',
      status: 'open',
      createdAt: new Date().toISOString(),
    };
    // Log-only until SupportTicket model exists
    console.log('[support.ticket]', JSON.stringify(payload));
    return {
      accepted: true,
      ticketId: `sup_${Date.now()}`,
      contacts: SUPPORT_CONTACTS,
      message: 'Ticket received. We will reply at your account email.',
    };
  }
}
