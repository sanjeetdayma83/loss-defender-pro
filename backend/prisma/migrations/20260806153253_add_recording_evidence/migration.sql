-- CreateEnum
CREATE TYPE "RecordingStatus" AS ENUM ('started', 'paused', 'completed', 'processing', 'processed', 'failed');

-- CreateEnum
CREATE TYPE "EvidenceStatus" AS ENUM ('pending', 'ready', 'archived', 'failed');

-- CreateTable
CREATE TABLE "recordings" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "warehouseId" TEXT NOT NULL,
    "stationId" TEXT,
    "operatorId" TEXT NOT NULL,
    "status" "RecordingStatus" NOT NULL DEFAULT 'started',
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "pausedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "durationSec" INTEGER,
    "segmentCount" INTEGER NOT NULL DEFAULT 0,
    "totalBytes" BIGINT NOT NULL DEFAULT 0,
    "b2Prefix" TEXT,
    "checksum" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "recordings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "recording_segments" (
    "id" TEXT NOT NULL,
    "recordingId" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "sequence" INTEGER NOT NULL,
    "b2Key" TEXT NOT NULL,
    "sizeBytes" BIGINT NOT NULL,
    "durationSec" INTEGER,
    "checksum" TEXT,
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recording_segments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "evidence" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "recordingId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "status" "EvidenceStatus" NOT NULL DEFAULT 'pending',
    "frameCount" INTEGER NOT NULL DEFAULT 0,
    "thumbnailKey" TEXT,
    "packKey" TEXT,
    "checksum" TEXT,
    "overlays" JSONB,
    "retentionUntil" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "evidence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "evidence_frames" (
    "id" TEXT NOT NULL,
    "evidenceId" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "sequence" INTEGER NOT NULL,
    "b2Key" TEXT NOT NULL,
    "timestampMs" INTEGER,
    "label" TEXT,
    "checksum" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "evidence_frames_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "recordings_companyId_status_idx" ON "recordings"("companyId", "status");

-- CreateIndex
CREATE INDEX "recordings_orderId_idx" ON "recordings"("orderId");

-- CreateIndex
CREATE INDEX "recordings_operatorId_idx" ON "recordings"("operatorId");

-- CreateIndex
CREATE INDEX "recording_segments_companyId_idx" ON "recording_segments"("companyId");

-- CreateIndex
CREATE UNIQUE INDEX "recording_segments_recordingId_sequence_key" ON "recording_segments"("recordingId", "sequence");

-- CreateIndex
CREATE UNIQUE INDEX "evidence_recordingId_key" ON "evidence"("recordingId");

-- CreateIndex
CREATE INDEX "evidence_companyId_status_idx" ON "evidence"("companyId", "status");

-- CreateIndex
CREATE INDEX "evidence_orderId_idx" ON "evidence"("orderId");

-- CreateIndex
CREATE INDEX "evidence_frames_companyId_idx" ON "evidence_frames"("companyId");

-- CreateIndex
CREATE UNIQUE INDEX "evidence_frames_evidenceId_sequence_key" ON "evidence_frames"("evidenceId", "sequence");

-- AddForeignKey
ALTER TABLE "recordings" ADD CONSTRAINT "recordings_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recordings" ADD CONSTRAINT "recordings_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recordings" ADD CONSTRAINT "recordings_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "Warehouse"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recordings" ADD CONSTRAINT "recordings_stationId_fkey" FOREIGN KEY ("stationId") REFERENCES "Station"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recordings" ADD CONSTRAINT "recordings_operatorId_fkey" FOREIGN KEY ("operatorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recording_segments" ADD CONSTRAINT "recording_segments_recordingId_fkey" FOREIGN KEY ("recordingId") REFERENCES "recordings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evidence" ADD CONSTRAINT "evidence_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evidence" ADD CONSTRAINT "evidence_recordingId_fkey" FOREIGN KEY ("recordingId") REFERENCES "recordings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evidence" ADD CONSTRAINT "evidence_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evidence_frames" ADD CONSTRAINT "evidence_frames_evidenceId_fkey" FOREIGN KEY ("evidenceId") REFERENCES "evidence"("id") ON DELETE CASCADE ON UPDATE CASCADE;
