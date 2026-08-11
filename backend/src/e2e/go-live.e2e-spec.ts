import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../app.module';

describe('Go-live API smoke E2E', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => app?.close());

  it('exposes health endpoint', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/health');
    expect([200, 204]).toContain(res.status);
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
