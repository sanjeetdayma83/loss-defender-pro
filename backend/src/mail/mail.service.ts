import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class MailService {
  private readonly log = new Logger(MailService.name);

  async send(to: string, subject: string, text: string) {
    const host = process.env.SMTP_HOST;
    if (!host) {
      this.log.warn(`[DEV MAIL] to=${to} subject=${subject}\n${text}`);
      return { mock: true };
    }
    // Optional: nodemailer when SMTP_* set
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
      this.log.error(`Mail failed: ${e?.message}`);
      this.log.warn(`[FALLBACK DEV MAIL] to=${to}\n${text}`);
      return { mock: true };
    }
  }

  otpEmail(purpose: string, code: string) {
    return `Your Loss Defender Pro code for ${purpose} is: ${code}\nValid for 15 minutes.`;
  }
}
