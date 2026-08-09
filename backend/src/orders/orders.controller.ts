import {
  Controller, Get, Post, Patch, Body, Param, Query, Req,
} from '@nestjs/common';
import { OrdersService } from './orders.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role, Marketplace, OrderStatus } from '@prisma/client';
import { Request } from 'express';
import {
  IsArray, IsEnum, IsInt, IsObject, IsOptional, IsString, IsUUID,
  MaxLength, Min, MinLength, ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

class OrderItemInputDto {
  @IsString() @MinLength(1) @MaxLength(80) sku: string;
  @IsString() @MinLength(1) @MaxLength(200) name: string;
  @IsInt() @Min(1) qty: number;
  @IsOptional() @IsString() @MaxLength(80) barcode?: string;
}

class CreateOrderDto {
  @IsOptional() @IsUUID() warehouseId?: string;
  @IsOptional() @IsEnum(Marketplace) marketplace?: Marketplace;
  @IsOptional() @IsString() customerName?: string;
  @IsOptional() @IsString() customerPhone?: string;
  @IsOptional() @IsObject() shippingAddress?: Record<string, unknown>;
  @IsOptional() @IsString() notes?: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => OrderItemInputDto)
  items: OrderItemInputDto[];
}

class AssignOrderDto {
  @IsUUID() operatorId: string;
  @IsOptional() @IsUUID() stationId?: string;
  @IsOptional() @IsUUID() warehouseId?: string;
}

class UpdateOrderStatusDto {
  @IsEnum(OrderStatus) status: OrderStatus;
}

class ScanItemDto {
  @IsString() @MinLength(1) barcodeOrSku: string;
}

class DispatchOrderDto {
  @IsString() @MinLength(3) awb: string;
  @IsOptional() @IsString() courier?: string;
}

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser, @Query('status') status?: OrderStatus) {
    return this.orders.list(user.companyId, status);
  }

  @Get(':id')
  getOne(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.orders.getOne(user.companyId, id);
  }

  @Post()
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.marketplace_manager, Role.super_admin)
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateOrderDto, @Req() req: Request) {
    return this.orders.create(user.companyId, user.sub, dto, req.ip);
  }

  @Post(':id/assign')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.super_admin)
  assign(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: AssignOrderDto, @Req() req: Request) {
    return this.orders.assign(user.companyId, id, user.sub, dto, req.ip);
  }

  @Patch(':id/status')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.packing_operator, Role.super_admin)
  updateStatus(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateOrderStatusDto, @Req() req: Request) {
    return this.orders.updateStatus(user.companyId, id, user.sub, dto, req.ip);
  }

  /** @deprecated Prefer POST /scanner/scan — keeps ScanEvent + scannedQty */
  @Post(':id/scan')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.packing_operator, Role.qc_operator, Role.super_admin)
  scan(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: ScanItemDto, @Req() req: Request) {
    return this.orders.scan(user.companyId, id, user.sub, dto, req.ip);
  }

  @Post(':id/dispatch')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.packing_operator, Role.super_admin)
  dispatch(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: DispatchOrderDto) {
    return this.orders.dispatch(user.companyId, id, dto.awb, dto.courier);
  }
}