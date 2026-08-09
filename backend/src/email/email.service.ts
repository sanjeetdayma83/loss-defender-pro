import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class EmailService {
  private readonly log = new Logger(EmailService.name);

  async send(to: string, subject: string, text: string, html?: string) {
    const host = process.env.SMTP_HOST;
    if (!host) {
      this.log.warn(`[DEV MAIL] to=${to} | ${subject}\n${text}`);
      return { mock: true, to, subject };
    }
    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const nodemailer = require('nodemailer');
      const transporter = nodemailer.createTransport({
        host,
        port: Number(process.env.SMTP_PORT ?? 587),
        secure: process.env.SMTP_SECURE === 'true',
        auth: process.env.SMTP_USER
          ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
          : undefined,
      });
      const info = await transporter.sendMail({
        from: process.env.SMTP_FROM ?? process.env.SMTP_USER ?? 'noreply@lossdefender.local',
        to,
        subject,
        text,
        html: html ?? `<pre>${text}</pre>`,
      });
      this.log.log(`sent ${info.messageId} → ${to}`);
      return { mock: false, messageId: info.messageId };
    } catch (e: any) {
      this.log.error(`SMTP failed: ${e?.message}`);
      this.log.warn(`[FALLBACK DEV MAIL] to=${to}\n${text}`);
      return { mock: true, error: e?.message };
    }
  }

  sendVerifyEmailOtp(to: string, code: string) {
    return this.send(
      to,
      'Verify your Loss Defender Pro email',
      `Your verification code is ${code}. Valid for 15 minutes.`,
    );
  }

  sendPasswordResetOtp(to: string, code: string) {
    return this.send(
      to,
      'Password reset code',
      `Your password reset code is ${code}. Valid for 15 minutes.`,
    );
  }

  sendInvite(to: string, acceptUrl: string, companyName?: string) {
    return this.send(
      to,
      'You are invited to Loss Defender Pro',
      `You have been invited${companyName ? ` to ${companyName}` : ''}.\n\nAccept your invite:\n${acceptUrl}\n\nThis link expires in 7 days.`,
      `<p>You have been invited${companyName ? ` to <b>${companyName}</b>` : ''}.</p>
       <p><a href="${acceptUrl}">Accept invite</a></p>
       <p>Link expires in 7 days.</p>`,
    );
  }
}
