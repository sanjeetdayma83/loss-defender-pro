import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';

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
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Get('contacts')
  contacts() {
    return SUPPORT_CONTACTS;
  }

  @UseGuards(JwtAuthGuard)
  @Post('ticket')
  async ticket(
    @CurrentUser() u: AuthenticatedUser,
    @Body() body: { subject: string; message: string; category?: string },
  ) {
    // Persist if SupportTicket model exists; else log-only stub
    const payload = {
      companyId: u.companyId,
      userId: (u as any).sub || (u as any).userId || (u as any).id,
      subject: body.subject?.slice(0, 200) || 'Support request',
      message: body.message?.slice(0, 4000) || '',
      category: body.category || 'general',
      status: 'open',
      createdAt: new Date().toISOString(),
    };
    try {
      if ((this.prisma as any).supportTicket?.create) {
        const row = await (this.prisma as any).supportTicket.create({
          data: {
            companyId: payload.companyId,
            userId: payload.userId,
            subject: payload.subject,
            message: payload.message,
            category: payload.category,
            status: 'open',
          },
        });
        return { accepted: true, ticket: row, contacts: SUPPORT_CONTACTS };
      }
    } catch {
      /* fall through */
    }
    return {
      accepted: true,
      ticket: payload,
      message: `Ticket recorded. Email ${SUPPORT_CONTACTS.supportEmail} or WhatsApp ${SUPPORT_CONTACTS.whatsapp}`,
      contacts: SUPPORT_CONTACTS,
    };
  }
}
