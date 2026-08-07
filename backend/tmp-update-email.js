const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  const user = await prisma.user.findFirst({
    where: { email: "owner2@test.ldp" },
  });
  if (!user) {
    console.log("User owner2@test.ldp not found — will register instead");
    return;
  }
  const updated = await prisma.user.update({
    where: { id: user.id },
    data: { email: "sanjeetdayma259@gmail.com" },
  });
  console.log("Updated:", updated.email, updated.id);
}
main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
