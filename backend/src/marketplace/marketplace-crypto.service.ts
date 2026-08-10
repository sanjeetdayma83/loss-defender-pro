import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';
@Injectable()
export class MarketplaceCryptoService {
  private readonly key: Buffer;
  constructor(config: ConfigService) { const raw=(config.get<string>('MARKETPLACE_CREDENTIAL_KEY')||process.env.MARKETPLACE_CREDENTIAL_KEY||'').trim(); if(!/^[0-9a-fA-F]{64}$/.test(raw)) throw new Error('MARKETPLACE_CREDENTIAL_KEY must be a 32-byte hex key'); this.key=Buffer.from(raw,'hex'); }
  encrypt(value?: string|null){if(value==null||value==='')return null;const iv=randomBytes(12);const c=createCipheriv('aes-256-gcm',this.key,iv);const data=Buffer.concat([c.update(value,'utf8'),c.final()]);return `enc:v1:${iv.toString('base64url')}:${c.getAuthTag().toString('base64url')}:${data.toString('base64url')}`;}
  decrypt(value?: string|null){if(value==null||value==='')return null;if(!value.startsWith('enc:v1:'))throw new BadRequestException('Unencrypted marketplace credential detected; reconnect the account');const [,v,iv,tag,data]=value.split(':');if(v!=='v1'||!iv||!tag||!data)throw new BadRequestException('Invalid encrypted marketplace credential');const d=createDecipheriv('aes-256-gcm',this.key,Buffer.from(iv,'base64url'));d.setAuthTag(Buffer.from(tag,'base64url'));return Buffer.concat([d.update(Buffer.from(data,'base64url')),d.final()]).toString('utf8');}
}
