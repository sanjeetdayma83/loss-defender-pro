import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const email = 'demo@lossdefender.in';
  if (await prisma.user.findFirst({ where: { email } })) {
    console.log('Seed skip — exists', email);
    return;
  }
  const passwordHash = await bcrypt.hash('Admin@123', 12);
  const company = await prisma.company.create({
    data: {
      companyName: 'Demo Logistics',
      email,
      phone: '+910000000000',
      status: 'active',
      plan: 'free' as any,
    } as any,
  });
  await prisma.user.create({
    data: {
      companyId: company.id,
      email,
      name: 'Demo Owner',
      phone: '+910000000000',
      role: 'owner',
      passwordHash,
      status: 'active',
      emailVerifiedAt: new Date(),
    } as any,
  });
  await prisma.warehouse.create({
    data: {
      companyId: company.id,
      name: 'Demo WH',
      code: 'DEMO-01',
      city: 'Delhi',
      state: 'DL',
      address: { line1: 'Seed' },
      status: 'active',
    } as any,
  });
  console.log('Seeded', email, 'Admin@123');
}

main().finally(() => prisma.$disconnect());