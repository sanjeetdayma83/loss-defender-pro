import { PrismaClient, Role, UserStatus, CompanyPlan, CompanyStatus } from "@prisma/client";
import * as bcrypt from "bcrypt";

const prisma = new PrismaClient();

async function main() {
  console.log("Seeding...");

  const company = await prisma.company.upsert({
    where: { email: "owner2@test.ldp" },
    update: {},
    create: {
      companyName: "Test Company 2",
      email: "owner2@test.ldp",
      phone: "9999999999",
      plan: CompanyPlan.free,
      status: CompanyStatus.active,
    },
  });

  const hash = await bcrypt.hash("Test@12345", 12);

  const user = await prisma.user.upsert({
    where: { email: "owner2@test.ldp" },
    update: {
      passwordHash: hash,
      status: UserStatus.active,
      role: Role.owner,
      failedLoginCount: 0,
      lockedUntil: null,
    },
    create: {
      email: "owner2@test.ldp",
      passwordHash: hash,
      name: "Owner Two",
      phone: "9999999999",
      role: Role.owner,
      status: UserStatus.active,
      companyId: company.id,
    },
  });

  console.log("✅ Company:", company.id, company.email);
  console.log("✅ User:", user.id, user.email, user.role);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
