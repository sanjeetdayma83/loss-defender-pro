import { PrismaClient } from '@prisma/client';
import { createCipheriv, randomBytes } from 'crypto';
const prisma = new PrismaClient();
function encrypt(value:string,key:Buffer){const iv=randomBytes(12);const c=createCipheriv('aes-256-gcm',key,iv);const data=Buffer.concat([c.update(value,'utf8'),c.final()]);return `enc:v1:${iv.toString('base64url')}:${c.getAuthTag().toString('base64url')}:${data.toString('base64url')}`;}
async function main(){const raw=(process.env.MARKETPLACE_CREDENTIAL_KEY||'').trim();if(!/^[0-9a-fA-F]{64}$/.test(raw))throw new Error('MARKETPLACE_CREDENTIAL_KEY must be a 32-byte hex key');const key=Buffer.from(raw,'hex');const rows=await prisma.marketplaceConnection.findMany();let updated=0;for(const row of rows){const data:any={};for(const field of ['accessToken','refreshToken','webhookSecret'] as const){const value=row[field];if(value&&!value.startsWith('enc:v1:'))data[field]=encrypt(value,key);}if(Object.keys(data).length){await prisma.marketplaceConnection.update({where:{id:row.id},data});updated++;}}console.log(`Re-encrypted ${updated} marketplace connection(s).`);}
main().catch((e)=>{console.error(e);process.exitCode=1}).finally(()=>prisma.$disconnect());
