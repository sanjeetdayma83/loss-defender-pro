import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { Role, CompanyPlan, UserStatus, WarehouseStatus, EvidenceStatus, ClaimStatus, ReturnStatus, OrderStatus, Marketplace, OrderItemStatus } from '@prisma/client';

export interface TestUser {
  id: string;
  email: string;
  password: string;
  companyId: string;
  role: Role;
  warehouseId?: string | null;
  accessToken: string;
  refreshToken: string;
}

export interface TestCompany {
  id: string;
  name: string;
  plan: CompanyPlan;
}

jest.mock('@nestjs/bullmq', () => {
  const createMockQueue = () => ({
    add: jest.fn().mockResolvedValue({}),
    process: jest.fn(),
    on: jest.fn(),
    close: jest.fn().mockResolvedValue({}),
  });

  return {
    ...jest.requireActual('@nestjs/bullmq'),
    BullModule: {
      forRoot: () => ({
        module: class MockBullModule {},
        providers: [],
        exports: [],
      }),
      registerQueue: () => ({
        module: class MockQueueModule {},
        providers: [
          { provide: 'BullQueue_email', useValue: createMockQueue() },
          { provide: 'BullQueue_evidence', useValue: createMockQueue() },
          { provide: 'BullQueue_notification', useValue: createMockQueue() },
        ],
        exports: ['BullQueue_email', 'BullQueue_evidence', 'BullQueue_notification'],
      }),
      getQueueToken: (name: string) => `BullQueue_${name}`,
      InjectQueue: () => () => {},
    },
    Queue: jest.fn().mockImplementation(() => createMockQueue()),
  };
});

export class TestHelper {
  static app: INestApplication;
  static module: TestingModule;
  static prisma: PrismaService;
  static jwtService: JwtService;

  static async setup() {
    this.module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    this.app = this.module.createNestApplication();
    await this.app.init();

    this.prisma = this.module.get(PrismaService);
    this.jwtService = this.module.get(JwtService);

    await this.cleanDatabase();
  }

  static async teardown() {
    await this.cleanDatabase();
    await this.app.close();
  }

  static async cleanDatabase() {
    await this.prisma.tokenBlacklist.deleteMany();
    await this.prisma.scanEvent.deleteMany();
    await this.prisma.orderItem.deleteMany();
    await this.prisma.order.deleteMany();
    await this.prisma.evidenceFrame.deleteMany();
    await this.prisma.evidence.deleteMany();
    await this.prisma.claim.deleteMany();
    await this.prisma.return.deleteMany();
    await this.prisma.user.deleteMany();
    await this.prisma.warehouse.deleteMany();
    await this.prisma.company.deleteMany();
  }

  static async createCompany(overrides: Partial<TestCompany> = {}): Promise<TestCompany> {
    const company = await this.prisma.company.create({
      data: {
        companyName: overrides.name || `Test Company ${Date.now()}`,
        email: `company${Date.now()}@test.com`,
        phone: `+91${Math.floor(Math.random() * 10000000000)}`,
        plan: overrides.plan || CompanyPlan.professional,
      },
    });
    return { id: company.id, name: company.companyName, plan: company.plan };
  }

  static async createUser(
    companyId: string,
    overrides: Partial<Omit<TestUser, 'id' | 'accessToken' | 'refreshToken'>> = {}
  ): Promise<TestUser> {
    const email = overrides.email || `user${Date.now()}@test.com`;
    const password = overrides.password || 'TestPass123!';
    const role = overrides.role || Role.owner;
    const warehouseId = overrides.warehouseId || null;

    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash: '$2b$10$testhash',
        companyId,
        role,
        warehouseId,
        name: `Test User ${Date.now()}`,
        phone: `+91${Math.floor(Math.random() * 10000000000)}`,
        status: UserStatus.active,
      },
    });

    const accessToken = this.jwtService.sign(
      { sub: user.id, email: user.email, companyId: user.companyId, role: user.role, warehouseId: user.warehouseId },
      { expiresIn: '15m', jwtid: `test-${Date.now()}` }
    );

    const refreshToken = this.jwtService.sign(
      { sub: user.id, type: 'refresh' },
      { expiresIn: '7d', jwtid: `refresh-${Date.now()}` }
    );

    return {
      id: user.id,
      email: user.email,
      password,
      companyId: user.companyId,
      role: user.role,
      warehouseId: user.warehouseId,
      accessToken,
      refreshToken,
    };
  }

  static async createWarehouse(companyId: string, name: string = `Warehouse ${Date.now()}`) {
    return this.prisma.warehouse.create({
      data: { 
        companyId, 
        name, 
        code: `WH${Date.now()}`,
        address: {},
        city: 'Test City',
        state: 'Test State',
        status: WarehouseStatus.active,
      },
    });
  }

  static async createOrder(companyId: string, warehouseId: string | null, overrides: any = {}) {
    return this.prisma.order.create({
      data: {
        companyId,
        warehouseId,
        marketplace: overrides.marketplace || Marketplace.manual,
        customerName: overrides.customerName || 'Test Customer',
        status: overrides.status || OrderStatus.synced,
        items: {
          create: overrides.items || [
            { sku: 'SKU-1', name: 'Item 1', qty: 2, barcode: null, scannedQty: 0, status: OrderItemStatus.pending },
          ],
        },
      },
      include: { items: true, warehouse: true },
    });
  }

  static async createEvidence(companyId: string, orderId: string, overrides: any = {}) {
    return this.prisma.evidence.create({
      data: {
        companyId,
        orderId,
        recordingId: overrides.recordingId || `rec-${Date.now()}`,
        status: overrides.status || EvidenceStatus.ready,
      },
    });
  }

  static async createClaim(companyId: string, orderId: string, overrides: any = {}) {
    return this.prisma.claim.create({
      data: {
        companyId,
        orderId,
        reason: overrides.reason || 'damaged',
        status: overrides.status || ClaimStatus.open,
      },
    });
  }

  static async createReturn(companyId: string, orderId: string, overrides: any = {}) {
    return this.prisma.return.create({
      data: {
        companyId,
        orderId,
        reason: overrides.reason || 'damaged',
        status: overrides.status || ReturnStatus.requested,
      },
    });
  }

  static getAuthHeaders(token: string) {
    return { Authorization: `Bearer ${token}` };
  }

  static getRequest(app: INestApplication) {
    return request(app.getHttpServer());
  }
}