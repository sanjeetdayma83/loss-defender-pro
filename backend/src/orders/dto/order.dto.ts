import { IsArray, IsEnum, IsInt, IsObject, IsOptional, IsString, IsUUID, MaxLength, Min, MinLength, ValidateNested } from "class-validator";
import { Type } from "class-transformer";
import { Marketplace, OrderStatus } from "@prisma/client";

export class OrderItemInputDto {
  @IsString() @MinLength(1) @MaxLength(80) sku: string;
  @IsString() @MinLength(1) @MaxLength(200) name: string;
  @IsInt() @Min(1) qty: number;
  @IsOptional() @IsString() @MaxLength(80) barcode?: string;
}

export class CreateOrderDto {
  @IsOptional() @IsUUID() warehouseId?: string;
  @IsOptional() @IsEnum(Marketplace) marketplace?: Marketplace;
  @IsOptional() @IsString() @MaxLength(120) marketplaceOrderId?: string;
  @IsOptional() @IsString() @MaxLength(120) customerName?: string;
  @IsOptional() @IsString() @MaxLength(20) customerPhone?: string;
  @IsOptional() @IsObject() shippingAddress?: Record<string, unknown>;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => OrderItemInputDto) items: OrderItemInputDto[];
}

export class AssignOrderDto {
  @IsUUID() operatorId: string;
  @IsOptional() @IsUUID() stationId?: string;
  @IsOptional() @IsUUID() warehouseId?: string;
}

export class UpdateOrderStatusDto {
  @IsEnum(OrderStatus) status: OrderStatus;
}

export class ScanItemDto {
  @IsString() @MinLength(1) @MaxLength(80) barcodeOrSku: string;
}
export class DispatchOrderDto {
  @IsString() @MinLength(3) @MaxLength(64)
  awb: string;

  @IsString() @MinLength(2) @MaxLength(64)
  courier: string;
}