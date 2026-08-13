import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class GoogleOAuthService {
  constructor(private readonly config: ConfigService) {}

  isConfigured(): boolean {
    return !!(
      this.config.get<string>('GOOGLE_CLIENT_ID') &&
      this.config.get<string>('GOOGLE_CLIENT_SECRET')
    );
  }

  getStartUrl() {
    if (!this.isConfigured()) {
      return {
        configured: false,
        authUrl: null as string | null,
        message: 'Set GOOGLE_CLIENT_ID',
      };
    }
    const clientId = this.config.get<string>('GOOGLE_CLIENT_ID')!;
    const redirect =
      this.config.get<string>('GOOGLE_REDIRECT_URI') ||
      'http://localhost:3000/api/v1/auth/google/callback';
    const scope = encodeURIComponent('openid email profile');
    const authUrl =
      'https://accounts.google.com/o/oauth2/v2/auth' +
      `?client_id=${encodeURIComponent(clientId)}` +
      `&redirect_uri=${encodeURIComponent(redirect)}` +
      `&response_type=code&scope=${scope}&access_type=offline&prompt=consent`;
    return { configured: true, authUrl, message: 'ok' };
  }

  /** Alias if something still calls getStartPayload */
  getStartPayload() {
    return this.getStartUrl();
  }

  async handleCallback(code: string) {
    if (!code) throw new BadRequestException('Missing code');
    if (!this.isConfigured()) {
      throw new BadRequestException('Google OAuth is not configured');
    }
    // Full token exchange + user upsert when keys exist — stub for compile/boot
    return {
      ok: false,
      message:
        'Google OAuth callback not fully wired. Set GOOGLE_CLIENT_ID/SECRET and implement token exchange.',
      codeReceived: true,
    };
  }
}