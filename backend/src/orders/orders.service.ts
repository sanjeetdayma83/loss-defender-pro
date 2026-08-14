import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OrderStatus, OrderItemStatus, Prisma } from '@prisma/client';
import { canTransition } from './order-transitions';
import { warehouseScope } from '../common/utils/warehouse-scope';
import { BillingService } from '../billing/billing.service';



@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService, private readonly billing: BillingService) {}
  list(companyId: string, status?: OrderStatus, warehouseId?: string, user?: { role?: string; warehouseId?: string | null }) {
    const scope = warehouseScope(user || {}, {
      ...(status ? { status } : {}),
      ...(warehouseId ? { warehouseId } : {}),
    });
    return this.prisma.order.findMany({
      where: { companyId, ...scope }, include: { items: true, warehouse: { select: { id: true, name: true, code: true } } }, orderBy: { createdAt: 'desc' }, take: 100 }); }
  async getOne(companyId: string, id: string) { const order = await this.prisma.order.findFirst({ where: { id, companyId }, include: { items: true, warehouse: true } }); if (!order) throw new NotFoundException('Order not found'); return order; }

  async create(companyId: string, actorId: string, dto: { warehouseId?: string; marketplace?: string; marketplaceOrderId?: string; customerName?: string; customerPhone?: string; shippingAddress?: Record<string, unknown>; notes?: string; items: { sku: string; name: string; qty: number; barcode?: string }[] }, _ip?: string) {
    if (!dto.items?.length) throw new BadRequestException('At least one item is required');
    await this.billing.assertOrderQuota(companyId);
    if (dto.warehouseId) { const wh = await this.prisma.warehouse.findFirst({ where: { id: dto.warehouseId, companyId } }); if (!wh) throw new BadRequestException('Warehouse not in your company'); }
    return this.prisma.order.create({ data: { companyId, warehouseId: dto.warehouseId, marketplace: (dto.marketplace as any) ?? 'manual', marketplaceOrderId: dto.marketplaceOrderId, customerName: dto.customerName, customerPhone: dto.customerPhone, shippingAddress: dto.shippingAddress as Prisma.InputJsonValue, notes: dto.notes, status: 'synced', items: { create: dto.items.map((i) => ({ sku: i.sku, name: i.name, qty: i.qty, barcode: i.barcode, scannedQty: 0, status: 'pending' })) } }, include: { items: true } });
  }
  async assign(companyId: string, id: string, _actorId: string, dto: { operatorId: string; stationId?: string; warehouseId?: string }, _ip?: string) { const order = await this.prisma.order.findFirst({ where: { id, companyId } }); if (!order) throw new NotFoundException('Order not found'); return this.prisma.order.update({ where: { id }, data: { assignedOperatorId: dto.operatorId, stationId: dto.stationId, warehouseId: dto.warehouseId ?? order.warehouseId, status: order.status === 'synced' ? 'queued' : order.status }, include: { items: true } }); }
  async updateStatus(companyId: string, id: string, _actorId: string, dto: { status: OrderStatus }, _ip?: string) { const order = await this.prisma.order.findFirst({ where: { id, companyId } }); if (!order) throw new NotFoundException('Order not found'); if (!canTransition(String(order.status), String(dto.status))) throw new BadRequestException(`Cannot transition from ${order.status} to ${dto.status}`); const data: Prisma.OrderUpdateInput = { status: dto.status }; if (dto.status === 'dispatched') data.dispatchedAt = new Date(); return this.prisma.order.update({ where: { id }, data, include: { items: true } }); }
  async scan(companyId: string, orderId: string, _actorId: string, dto: { barcodeOrSku: string }, _ip?: string) { const order = await this.prisma.order.findFirst({ where: { id: orderId, companyId }, include: { items: true } }); if (!order) throw new NotFoundException('Order not found'); if (!['synced','queued','packing','recording','scanned'].includes(order.status)) throw new BadRequestException(`Cannot scan in status ${order.status}`); const code=dto.barcodeOrSku.trim(); const item=order.items.find(i=>i.sku===code||i.barcode===code); if(!item) throw new BadRequestException(`Barcode/SKU "${code}" is not on this order`); if(item.scannedQty>=item.qty) throw new ConflictException(`SKU ${item.sku} already fully scanned`); const newQty=item.scannedQty+1; const itemStatus:OrderItemStatus=newQty>=item.qty?'matched':'partial'; await this.prisma.orderItem.update({where:{id:item.id},data:{scannedQty:newQty,status:itemStatus}}); const refreshed=await this.prisma.order.findFirst({where:{id:orderId,companyId},include:{items:true}}); const allMatched=refreshed!.items.every(i=>i.scannedQty>=i.qty); if(allMatched) await this.prisma.order.update({where:{id:orderId,companyId},data:{status:'scanned'}}); else if(['synced','queued'].includes(refreshed!.status)) await this.prisma.order.update({where:{id:orderId,companyId},data:{status:'packing'}}); return {scan:{sku:item.sku,scannedQty:newQty,qty:item.qty,itemStatus,allMatched},order:await this.getOne(companyId,orderId)}; }
  async dispatch(companyId:string,id:string,awb:string,courier?:string){const order=await this.prisma.order.findFirst({where:{id,companyId}});if(!order)throw new NotFoundException('Order not found');if(!['scanned','evidence_ready'].includes(order.status))throw new BadRequestException(`Cannot dispatch from ${order.status}; need scanned or evidence_ready`);return this.prisma.order.update({where:{id},data:{status:'dispatched',awb,courier:courier??undefined,dispatchedAt:new Date()},include:{items:true}});}
}
