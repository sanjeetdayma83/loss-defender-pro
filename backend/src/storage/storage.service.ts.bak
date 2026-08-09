import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private client: S3Client | null = null;
  private bucket: string | null = null;
  private configured = false;

  constructor(private readonly config: ConfigService) {
    const keyId = this.config.get<string>('B2_KEY_ID');
    // Support both names
    const appKey =
      this.config.get<string>('B2_APP_KEY') ||
      this.config.get<string>('B2_APPLICATION_KEY');
    const bucket = this.config.get<string>('B2_BUCKET');
    const endpoint = this.config.get<string>('B2_ENDPOINT');
    const region = this.config.get<string>('B2_REGION') || 'us-east-005';

    if (
      keyId &&
      appKey &&
      bucket &&
      endpoint &&
      !keyId.includes('PLACE_YOUR') &&
      !appKey.includes('PLACE_YOUR')
    ) {
      this.client = new S3Client({
        region,
        endpoint,
        credentials: { accessKeyId: keyId, secretAccessKey: appKey },
        forcePathStyle: true,
      });
      this.bucket = bucket;
      this.configured = true;
      this.logger.log(`B2 storage configured → bucket=${bucket}`);
    } else {
      this.logger.warn('B2 not configured — set B2_KEY_ID + B2_APPLICATION_KEY + B2_BUCKET + B2_ENDPOINT');
    }
  }

  isConfigured() {
    return this.configured;
  }

  buildKey(companyId: string, purpose: string, filename?: string) {
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = String(now.getUTCMonth() + 1).padStart(2, '0');
    const id = randomUUID();
    const name = filename || id;
    return `${companyId}/${purpose}/${y}/${m}/${name}`;
  }

  recordingSegmentKey(companyId: string, recordingId: string, index: number) {
    return this.buildKey(companyId, 'recordings', `${recordingId}/seg_${index}.webm`);
  }

  evidencePackKey(companyId: string, evidenceId: string) {
    return this.buildKey(companyId, 'evidence', `${evidenceId}/pack.json`);
  }

  async presignPut(key: string, contentType = 'application/octet-stream', expiresIn = 900) {
    if (!this.configured || !this.client || !this.bucket) {
      return {
        configured: false,
        uploadUrl: null as string | null,
        key,
        expiresIn,
        message: 'Set B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET, B2_ENDPOINT in .env',
      };
    }
    const cmd = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });
    const uploadUrl = await getSignedUrl(this.client, cmd, { expiresIn });
    return { configured: true, uploadUrl, key, expiresIn, contentType };
  }

  async presignGet(key: string, expiresIn = 900) {
    if (!this.configured || !this.client || !this.bucket) {
      return { configured: false, downloadUrl: null as string | null, key };
    }
    const cmd = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    const downloadUrl = await getSignedUrl(this.client, cmd, { expiresIn });
    return { configured: true, downloadUrl, key, expiresIn };
  }
}
