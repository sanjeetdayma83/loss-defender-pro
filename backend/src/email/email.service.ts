import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class EmailService {
  private readonly log = new Logger(EmailService.name);

  async send(to: string, subject: string, text: string) {
    const host = process.env.SMTP_HOST;
    if (!host) {
      this.log.warn(`[DEV MAIL] to=${to} | ${subject}\n${text}`);
      return { mock: true };
    }
    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const nodemailer = require('nodemailer');
      const transporter = nodemailer.createTransport({
        host,
        port: Number(process.env.SMTP_PORT ?? 587),
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      });
      await transporter.sendMail({
        from: process.env.SMTP_FROM ?? process.env.SMTP_USER,
        to,
        subject,
        text,
      });
      return { mock: false };
    } catch (e: any) {
      this.log.error(`SMTP failed: ${e?.message}`);
      this.log.warn(`[FALLBACK DEV MAIL] to=${to}\n${text}`);
      return { mock: true };
    }
  }

  sendPasswordResetOtp(to: string, code: string) {
    return this.send(
      to,
      'Password reset code',
      `Your Loss Defender Pro code is ${code}. Valid for 15 minutes.`,
    );
  }

  sendVerifyEmailOtp(to: string, code: string) {
    return this.send(
      to,
      'Verify your email',
      `Your verification code is ${code}. Valid for 15 minutes.`,
    );
  }

  sendInvite(to: string, link: string) {
    return this.send(
      to,
      'You are invited to Loss Defender Pro',
      `Accept your invite: ${link}`,
    );
  }
}
