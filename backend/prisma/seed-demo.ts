import { PrismaClient, Role, WarehouseStatus, StationStatus, UserStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const company = await prisma.company.findFirst({
    where: { status: { not: 'deleted' } },
    orderBy: { createdAt: 'asc' },
  });
  if (!company) {
    console.log('No company — register first');
    return;
  }
  console.log('Company:', company.companyName);

  let wh = await prisma.warehouse.findFirst({
    where: { companyId: company.id },
    orderBy: { createdAt: 'asc' },
  });
  if (!wh) {
    wh = await prisma.warehouse.create({
      data: {
        companyId: company.id,
        name: 'Main Warehouse',
        code: 'WH-01',
        address: { line1: 'Sector 62', pincode: '201301' },
        city: 'Noida',
        state: 'UP',
        country: 'India',
        status: WarehouseStatus.active,
      },
    });
  }
  console.log('Warehouse:', wh.name);

  for (const s of [
    { stationName: 'Pack Table 1', stationId: 'ST-01' },
    { stationName: 'Pack Table 2', stationId: 'ST-02' },
    { stationName: 'QC Desk 1', stationId: 'QC-01' },
  ]) {
    const ex = await prisma.station.findFirst({
      where: { warehouseId: wh.id, stationId: s.stationId },
    });
    if (!ex) {
      await prisma.station.create({
        data: {
          warehouseId: wh.id,
          stationName: s.stationName,
          stationId: s.stationId,
          status: StationStatus.offline,
        },
      });
      console.log('Station:', s.stationId);
    }
  }

  const owner = await prisma.user.findFirst({
    where: { companyId: company.id, role: Role.owner },
  });
  if (owner && !owner.warehouseId) {
    await prisma.user.update({
      where: { id: owner.id },
      data: { warehouseId: wh.id },
    });
  }

  // Ensure packing_operator exists & active
  const hash = await bcrypt.hash('Test@12345', 12);
  const packingOps = [
    { email: 'op1@test.ldp', name: 'Pack Operator 1', phone: '9876500001' },
    { email: 'op2@test.ldp', name: 'Priya Sharma', phone: '9876500002' },
  ];
  for (const o of packingOps) {
    const u = await prisma.user.findFirst({ where: { email: o.email } });
    if (!u) {
      await prisma.user.create({
        data: {
          companyId: company.id,
          email: o.email,
          name: o.name,
          phone: o.phone,
          role: Role.packing_operator,
          passwordHash: hash,
          status: UserStatus.active,
          warehouseId: wh.id,
        },
      });
      console.log('Created packing_operator:', o.email);
    } else {
      await prisma.user.update({
        where: { id: u.id },
        data: {
          role: Role.packing_operator,
          status: UserStatus.active,
          warehouseId: wh.id,
        },
      });
      console.log('Updated packing_operator:', o.email);
    }
  }

  // Other roles
  for (const o of [
    { email: 'qc1@test.ldp', name: 'Suresh QC', role: Role.qc_operator, phone: '9876500003' },
    { email: 'sup1@test.ldp', name: 'Amit Supervisor', role: Role.supervisor, phone: '9876500004' },
    { email: 'mgr1@test.ldp', name: 'Neha Manager', role: Role.manager, phone: '9876500005' },
  ]) {
    const u = await prisma.user.findFirst({ where: { email: o.email } });
    if (!u) {
      await prisma.user.create({
        data: {
          companyId: company.id,
          email: o.email,
          name: o.name,
          phone: o.phone,
          role: o.role,
          passwordHash: hash,
          status: UserStatus.active,
          warehouseId: wh.id,
        },
      });
      console.log('Created:', o.email, o.role);
    }
  }

  console.log('Seed complete — packing_operator ready');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
