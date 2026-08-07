const { PrismaClient } = require("@prisma/client");
const bcrypt = require("bcrypt");

const prisma = new PrismaClient();

async function main() {
  // Existing company lo
  const companies = await prisma.company.findMany({ take: 1 });
  if (companies.length === 0) {
    console.log("No company found!");
    return;
  }
  const company = companies[0];
  console.log("Using company:", company.id, company.email);

  const hash = await bcrypt.hash("Test@12345", 12);

  const user = await prisma.user.upsert({
    where: { email: "owner2@test.ldp" },
    update: {
      passwordHash: hash,
      status: "active",
      role: "owner",
      failedLoginCount: 0,
      lockedUntil: null,
    },
    create: {
      email: "owner2@test.ldp",
      passwordHash: hash,
      name: "Owner Two",
      phone: "9999999999",
      role: "owner",
      status: "active",
      companyId: company.id,
    },
  });

  console.log("✅ User created/updated:");
  console.log("  id   :", user.id);
  console.log("  email:", user.email);
  console.log("  role :", user.role);
  console.log("  status:", user.status);
}

main()
  .catch(e => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
