import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class EmailService {
  private readonly log = new Logger(EmailService.name);

  async send(to: string, subject: string, text: string, html?: string) {
    const host = process.env.SMTP_HOST;
    if (!host || host.includes('PLACE_YOUR')) {
      if (process.env.NODE_ENV === 'production') throw new Error('SMTP is not configured');
      this.log.warn(`[DEV MAIL] to=${to} | ${subject}\n${text}`);
      return { mock: true, to, subject };
    }
    const nodemailer = require('nodemailer');
    const transporter = nodemailer.createTransport({
      host, port: Number(process.env.SMTP_PORT ?? 587), secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    });
    const info = await transporter.sendMail({ from: process.env.SMTP_FROM ?? process.env.SMTP_USER ?? 'noreply@lossdefender.local', to, subject, text, html: html ?? `<pre>${text}</pre>` });
    this.log.log(`sent ${info.messageId} → ${to}`);
    return { mock: false, messageId: info.messageId };
  }

  sendGeneric(to: string, subject: string, text: string) { return this.send(to, subject, text); }
  sendPasswordResetOtp(to: string, code: string) { return this.send(to, 'Password Reset Code — Loss Defender Pro', `Your password reset code is: ${code}\n\nExpires in 15 minutes.`); }
  sendVerifyEmailOtp(to: string, code: string) { return this.send(to, 'Verify your email — Loss Defender Pro', `Your verification code is: ${code}`); }
  sendInvite(to: string, acceptUrl: string) { return this.send(to, 'You are invited — Loss Defender Pro', `You have been invited to Loss Defender Pro.\n\nAccept: ${acceptUrl}`); }
}
