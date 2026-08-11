import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request = require('supertest');
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';

describe('Go-live API smoke E2E', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      // These smoke tests validate the HTTP/API contract and authentication
      // boundaries. They must not depend on a developer's or production
      // database being reachable, so Prisma connectivity is replaced with a
      // no-op test double. Database connectivity is validated separately by
      // deployment/integration checks.
      .overrideProvider(PrismaService)
      .useValue({
        $connect: jest.fn().mockResolvedValue(undefined),
        $disconnect: jest.fn().mockResolvedValue(undefined),
      })
      .compile();

    app = moduleRef.createNestApplication();

    // Keep the E2E application contract identical to production bootstrap.
    app.setGlobalPrefix('api/v1');

    await app.init();
  }, 30000);

  afterAll(async () => {
    await app?.close();
  }, 10000);

  it('exposes health endpoint', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body?.status).toBe('ok');
  });

  it('keeps billing plan catalogue public', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/billing/plans');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body?.data ?? res.body)).toBe(true);
  });

  it('rejects protected endpoint without authentication', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/orders');
    expect([401, 403]).toContain(res.status);
  });
});
