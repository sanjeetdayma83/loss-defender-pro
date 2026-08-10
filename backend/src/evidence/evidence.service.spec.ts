import { execFile } from 'child_process';
import { promisify } from 'util';
import { createHash } from 'crypto';
import { EvidenceService } from './evidence.service';

const execFileAsync = promisify(execFile);

describe('EvidenceService production pipeline', () => {
  jest.setTimeout(120_000);

  it('extracts frames with the configured ffmpeg binary and produces a ready evidence pack', async () => {
    const { stdout } = await execFileAsync('ffmpeg', [
      '-hide_banner', '-loglevel', 'error',
      '-f', 'lavfi', '-i', 'color=c=black:s=160x120:d=1',
      '-c:v', 'libvpx-vp9', '-deadline', 'realtime', '-f', 'webm', 'pipe:1',
    ], { maxBuffer: 10 * 1024 * 1024, encoding: 'buffer' });
    const video = Buffer.from(stdout as Buffer);
    expect(video.length).toBeGreaterThan(0);

    const segmentChecksum = createHash('sha256').update(video).digest('hex');
    const uploaded: Record<string, Buffer> = {};
    const prisma = {
      recording: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'r1', companyId: 'c1', orderId: 'o1',
          segments: [{ sequence: 0, b2Key: 'c1/recordings/r1/seg_0.webm', sizeBytes: video.length, checksum: segmentChecksum }],
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      evidence: {
        findFirst: jest.fn().mockResolvedValue({ id: 'e1', companyId: 'c1', status: 'pending', packKey: null }),
        update: jest.fn().mockResolvedValue({ id: 'e1', status: 'ready', frameCount: 1, packKey: 'c1/evidence/e1/pack.json' }),
      },
      evidenceFrame: {
        upsert: jest.fn().mockResolvedValue({}),
      },
      order: {
        update: jest.fn().mockResolvedValue({}),
      },
    } as any;
    const storage = {
      isConfigured: jest.fn().mockReturnValue(true),
      downloadBuffer: jest.fn().mockResolvedValue(video),
      uploadBuffer: jest.fn().mockImplementation(async (key: string, body: Buffer) => {
        uploaded[key] = Buffer.from(body);
        return { configured: true, key, etag: 'etag' };
      }),
      presignGet: jest.fn().mockResolvedValue({ configured: true, downloadUrl: 'https://signed.example/e1', key: 'c1/evidence/e1/pack.json', expiresIn: 900 }),
    } as any;

    const service = new EvidenceService(prisma, storage);
    const result = await service.processRecordingEvidence('c1', 'r1', 'e1', 1);

    expect(prisma.evidenceFrame.upsert).toHaveBeenCalled();
    expect(Object.keys(uploaded).some((key) => key.endsWith('/pack.json'))).toBe(true);
    expect(result.status).toBe('ready');
  });

  it('only issues a signed download URL for ready evidence', async () => {
    const prisma = {
      evidence: { findFirst: jest.fn().mockResolvedValue({ id: 'e1', companyId: 'c1', status: 'ready', packKey: 'c1/evidence/e1/pack.json' }) },
    } as any;
    const storage = {
      isConfigured: jest.fn().mockReturnValue(true),
      presignGet: jest.fn().mockResolvedValue({ configured: true, downloadUrl: 'https://signed.example/e1', key: 'c1/evidence/e1/pack.json', expiresIn: 900 }),
    } as any;
    const service = new EvidenceService(prisma, storage);
    const result = await service.getDownloadUrl('c1', 'e1');
    expect(result.expiresIn).toBe(900);
    expect(storage.presignGet).toHaveBeenCalledWith('c1/evidence/e1/pack.json', 900);
  });
});
