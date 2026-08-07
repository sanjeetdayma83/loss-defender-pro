import { Controller, Get } from "@nestjs/common";
import { Public } from "../common/decorators/public.decorator";
import { PrismaService } from "../prisma/prisma.service";
import { StorageService } from "../storage/storage.service";

@Controller()
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  @Public()
  @Get("health")
  health() {
    return { status: "ok", service: "loss-defender-pro", ts: new Date().toISOString() };
  }

  @Public()
  @Get("ready")
  async ready() {
    let db = false;
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      db = true;
    } catch {
      db = false;
    }
    return {
      status: db ? "ready" : "degraded",
      checks: {
        database: db,
        storage: this.storage.isConfigured(),
      },
      ts: new Date().toISOString(),
    };
  }
}