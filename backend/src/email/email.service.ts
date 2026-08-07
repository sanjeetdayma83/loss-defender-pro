import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter | null = null;
  private from: string;

  constructor(private readonly config: ConfigService) {
    const host = this.config.get<string>('SMTP_HOST');
    const port = this.config.get<number>('SMTP_PORT') || 587;
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASS');
    this.from = this.config.get<string>('SMTP_FROM') || 'Loss Defender Pro <noreply@localhost>';

    if (host && user && pass && !pass.includes('PLACE_YOUR')) {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure: false, // 587 = STARTTLS
        auth: { user, pass },
      });
      this.logger.log(`SMTP configured → ${host}:${port}`);
    } else {
      this.logger.warn('SMTP not configured — emails will be logged only');
    }
  }

  async sendMail(to: string, subject: string, html: string, text?: string) {
    if (!this.transporter) {
      this.logger.warn(`[DEV EMAIL] To: ${to} | Subject: ${subject}`);
      this.logger.warn(text || html);
      return { success: false, dev: true };
    }

    try {
      const info = await this.transporter.sendMail({
        from: this.from,
        to,
        subject,
        html,
        text: text || html.replace(/<[^>]*>/g, ''),
      });
      this.logger.log(`Email sent → ${to} | id: ${info.messageId}`);
      return { success: true, messageId: info.messageId };
    } catch (e: any) {
      this.logger.error(`Email failed → ${to}: ${e.message}`);
      return { success: false, error: e.message };
    }
  }

  async sendPasswordResetOtp(to: string, code: string) {
    const subject = 'Password Reset Code — Loss Defender Pro';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
        <h2>Password Reset</h2>
        <p>Your one-time code is:</p>
        <div style="font-size: 32px; font-weight: bold; letter-spacing: 6px; margin: 20px 0;">
          ${code}
        </div>
        <p>This code expires in <strong>15 minutes</strong>.</p>
        <p style="color:#666; font-size:13px;">If you did not request this, you can safely ignore this email.</p>
      </div>
    `;
    return this.sendMail(to, subject, html);
  }
}
