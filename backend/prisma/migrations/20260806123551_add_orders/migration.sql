-- CreateEnum
CREATE TYPE "Marketplace" AS ENUM ('amazon', 'flipkart', 'meesho', 'shopify', 'woocommerce', 'manual');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('synced', 'queued', 'packing', 'recording', 'scanned', 'evidence_ready', 'dispatched', 'shipped', 'claimed', 'returned', 'closed');

-- CreateEnum
CREATE TYPE "OrderItemStatus" AS ENUM ('pending', 'matched', 'partial', 'mismatch');

-- CreateTable
CREATE TABLE "Order" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "warehouseId" TEXT,
    "marketplace" "Marketplace" NOT NULL DEFAULT 'manual',
    "marketplaceOrderId" TEXT,
    "status" "OrderStatus" NOT NULL DEFAULT 'synced',
    "assignedOperatorId" TEXT,
    "stationId" TEXT,
    "customerName" TEXT,
    "customerPhone" TEXT,
    "shippingAddress" JSONB,
    "awb" TEXT,
    "courier" TEXT,
    "dispatchedAt" TIMESTAMP(3),
    "deliveredAt" TIMESTAMP(3),
    "metadata" JSONB,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Order_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OrderItem" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "sku" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "qty" INTEGER NOT NULL,
    "scannedQty" INTEGER NOT NULL DEFAULT 0,
    "status" "OrderItemStatus" NOT NULL DEFAULT 'pending',
    "barcode" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "OrderItem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Order_companyId_status_idx" ON "Order"("companyId", "status");

-- CreateIndex
CREATE INDEX "Order_companyId_warehouseId_idx" ON "Order"("companyId", "warehouseId");

-- CreateIndex
CREATE INDEX "Order_assignedOperatorId_idx" ON "Order"("assignedOperatorId");

-- CreateIndex
CREATE INDEX "Order_marketplace_marketplaceOrderId_idx" ON "Order"("marketplace", "marketplaceOrderId");

-- CreateIndex
CREATE INDEX "OrderItem_orderId_idx" ON "OrderItem"("orderId");

-- CreateIndex
CREATE INDEX "OrderItem_sku_idx" ON "OrderItem"("sku");

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "Warehouse"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_assignedOperatorId_fkey" FOREIGN KEY ("assignedOperatorId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_stationId_fkey" FOREIGN KEY ("stationId") REFERENCES "Station"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrderItem" ADD CONSTRAINT "OrderItem_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE CASCADE ON UPDATE CASCADE;
