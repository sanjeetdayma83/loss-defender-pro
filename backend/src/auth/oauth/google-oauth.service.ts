import { Injectable } from '@nestjs/common';

@Injectable()
export class GoogleOAuthService {
  getStartUrl(redirectUri?: string) {
    const clientId = process.env.GOOGLE_CLIENT_ID || '';
    if (!clientId || clientId.includes('PLACE')) {
      return { configured: false, authUrl: null, message: 'Set GOOGLE_CLIENT_ID' };
    }
    const redirect = redirectUri || process.env.GOOGLE_REDIRECT_URI || 'http://localhost:3000/api/v1/auth/google/callback';
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirect)}&response_type=code&scope=openid%20email%20profile`;
    return { configured: true, authUrl };
  }
}
