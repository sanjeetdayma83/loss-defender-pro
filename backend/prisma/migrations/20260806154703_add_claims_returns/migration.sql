-- CreateEnum
CREATE TYPE "ClaimStatus" AS ENUM ('open', 'investigating', 'approved', 'rejected', 'escalated', 'closed');

-- CreateEnum
CREATE TYPE "ReturnStatus" AS ENUM ('requested', 'received', 'inspecting', 'refunded', 'restocked', 'rejected', 'closed');

-- CreateTable
CREATE TABLE "claims" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "marketplace" TEXT,
    "description" TEXT,
    "status" "ClaimStatus" NOT NULL DEFAULT 'open',
    "evidenceIds" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "decisionNote" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "closedAt" TIMESTAMP(3),

    CONSTRAINT "claims_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "returns" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "reason" TEXT,
    "status" "ReturnStatus" NOT NULL DEFAULT 'requested',
    "conditionNote" TEXT,
    "decision" TEXT,
    "recordingId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "closedAt" TIMESTAMP(3),

    CONSTRAINT "returns_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "claims_companyId_status_idx" ON "claims"("companyId", "status");

-- CreateIndex
CREATE INDEX "claims_orderId_idx" ON "claims"("orderId");

-- CreateIndex
CREATE INDEX "returns_companyId_status_idx" ON "returns"("companyId", "status");

-- CreateIndex
CREATE INDEX "returns_orderId_idx" ON "returns"("orderId");

-- AddForeignKey
ALTER TABLE "claims" ADD CONSTRAINT "claims_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "claims" ADD CONSTRAINT "claims_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
