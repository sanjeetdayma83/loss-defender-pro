import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class EmailService {
  private readonly log = new Logger(EmailService.name);

  async send(to: string, subject: string, text: string, html?: string) {
    const host = process.env.SMTP_HOST;
    if (!host || host.includes('PLACE_YOUR')) {
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

  sendPasswordResetOtp(to: string, code: string) {
    const subject = 'Password Reset Code — Loss Defender Pro';
    const text = `Your password reset code is: ${code}\n\nExpires in 15 minutes.`;
    const html = `<div style="font-family:Arial,sans-serif"><h2>Password Reset</h2><p>Code: <b style="font-size:24px">${code}</b></p><p>Expires in 15 minutes.</p></div>`;
    return this.send(to, subject, text, html);
  }

  sendVerifyEmailOtp(to: string, code: string) {
    const subject = 'Verify your email — Loss Defender Pro';
    const text = `Your verification code is: ${code}`;
    const html = `<div style="font-family:Arial,sans-serif"><h2>Email Verification</h2><p>Code: <b style="font-size:24px">${code}</b></p></div>`;
    return this.send(to, subject, text, html);
  }

  sendInvite(to: string, acceptUrl: string) {
    const subject = 'You are invited — Loss Defender Pro';
    const text = `You have been invited to Loss Defender Pro.\n\nAccept: ${acceptUrl}\n\nIf you did not expect this, ignore this email.`;
    const html = `
      <div style="font-family:Arial,sans-serif;max-width:480px">
        <h2>You're invited</h2>
        <p>You have been invited to join Loss Defender Pro.</p>
        <p><a href="${acceptUrl}" style="display:inline-block;padding:12px 20px;background:#2563eb;color:#fff;text-decoration:none;border-radius:6px">Accept invite</a></p>
        <p style="color:#666;font-size:13px">Or open: ${acceptUrl}</p>
      </div>`;
    return this.send(to, subject, text, html);
  }
}
