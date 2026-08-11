import { Injectable } from '@nestjs/common';

@Injectable()
export class GoogleOAuthService {
  getStartUrl(redirectUri?: string) {
    const clientId = process.env.GOOGLE_CLIENT_ID || '';
    if (!clientId || clientId.includes('PLACE')) {
      return { configured: false, provider: 'google', authUrl: null, message: 'Set GOOGLE_CLIENT_ID' };
    }
    const redirect = redirectUri || process.env.GOOGLE_REDIRECT_URI || 'http://localhost:3000/api/v1/auth/google/callback';
    const authUrl =
      `https://accounts.google.com/o/oauth2/v2/auth?client_id=${encodeURIComponent(clientId)}` +
      `&redirect_uri=${encodeURIComponent(redirect)}&response_type=code&scope=openid%20email%20profile&access_type=offline`;
    return { configured: true, provider: 'google', authUrl };
  }
}

@Injectable()
export class MicrosoftOAuthService {
  getStartUrl(redirectUri?: string) {
    const clientId = process.env.MICROSOFT_CLIENT_ID || '';
    if (!clientId || clientId.includes('PLACE')) {
      return { configured: false, provider: 'microsoft', authUrl: null, message: 'Set MICROSOFT_CLIENT_ID' };
    }
    const tenant = process.env.MICROSOFT_TENANT || 'common';
    const redirect = redirectUri || process.env.MICROSOFT_REDIRECT_URI || 'http://localhost:3000/api/v1/auth/microsoft/callback';
    const authUrl =
      `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/authorize?client_id=${encodeURIComponent(clientId)}` +
      `&response_type=code&redirect_uri=${encodeURIComponent(redirect)}&scope=openid%20email%20profile%20offline_access`;
    return { configured: true, provider: 'microsoft', authUrl };
  }
}
