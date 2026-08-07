const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function main() {
  const users = await prisma.user.findMany({ select: { id: true, email: true, role: true, status: true, companyId: true } });
  console.log(JSON.stringify(users, null, 2));
  const companies = await prisma.company.findMany({ select: { id: true, email: true, companyName: true } });
  console.log(JSON.stringify(companies, null, 2));
}
main().finally(() => prisma.$disconnect());
