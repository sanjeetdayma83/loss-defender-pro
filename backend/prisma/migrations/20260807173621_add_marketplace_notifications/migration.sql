-- CreateEnum
CREATE TYPE "MarketplaceProvider" AS ENUM ('amazon', 'flipkart', 'shopify', 'manual', 'other');

-- CreateEnum
CREATE TYPE "MarketplaceConnectionStatus" AS ENUM ('connected', 'disconnected', 'error', 'pending');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('in_app', 'email', 'sms', 'push', 'whatsapp');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('pending', 'sent', 'failed', 'read');

-- CreateTable
CREATE TABLE "marketplace_connections" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "provider" "MarketplaceProvider" NOT NULL,
    "storeName" TEXT,
    "externalId" TEXT,
    "accessToken" TEXT,
    "refreshToken" TEXT,
    "webhookSecret" TEXT,
    "status" "MarketplaceConnectionStatus" NOT NULL DEFAULT 'pending',
    "lastSyncAt" TIMESTAMP(3),
    "meta" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "marketplace_connections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "userId" TEXT,
    "channel" "NotificationChannel" NOT NULL DEFAULT 'in_app',
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "data" JSONB,
    "status" "NotificationStatus" NOT NULL DEFAULT 'pending',
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "marketplace_connections_companyId_idx" ON "marketplace_connections"("companyId");

-- CreateIndex
CREATE INDEX "notifications_companyId_userId_idx" ON "notifications"("companyId", "userId");

-- CreateIndex
CREATE INDEX "notifications_companyId_status_idx" ON "notifications"("companyId", "status");

-- AddForeignKey
ALTER TABLE "marketplace_connections" ADD CONSTRAINT "marketplace_connections_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
