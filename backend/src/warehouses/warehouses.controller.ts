import { Controller, Get, Post, Patch, Body, Param, Req } from '@nestjs/common';
import { WarehousesService } from './warehouses.service';
import {
  CreateWarehouseDto,
  UpdateWarehouseDto,
  CreateStationDto,
  UpdateStationDto,
} from './dto/warehouse.dto';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { Request } from 'express';

@Controller('warehouses')
export class WarehousesController {
  constructor(private readonly warehouses: WarehousesService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser) {
    return this.warehouses.list(user.companyId);
  }

  @Get(':id')
  getOne(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.warehouses.getOne(user.companyId, id);
  }

  @Post()
  @Roles(Role.owner, Role.manager, Role.super_admin)
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateWarehouseDto,
    @Req() req: Request,
  ) {
    return this.warehouses.create(user.companyId, user.sub, dto, req.ip);
  }

  @Patch(':id')
  @Roles(Role.owner, Role.manager, Role.super_admin)
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateWarehouseDto,
    @Req() req: Request,
  ) {
    return this.warehouses.update(user.companyId, id, user.sub, dto, req.ip);
  }

  @Post(':warehouseId/stations')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.super_admin)
  createStation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('warehouseId') warehouseId: string,
    @Body() dto: CreateStationDto,
    @Req() req: Request,
  ) {
    return this.warehouses.createStation(
      user.companyId,
      warehouseId,
      user.sub,
      dto,
      req.ip,
    );
  }

  @Patch(':warehouseId/stations/:stationId')
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.super_admin)
  updateStation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('warehouseId') warehouseId: string,
    @Param('stationId') stationId: string,
    @Body() dto: UpdateStationDto,
    @Req() req: Request,
  ) {
    return this.warehouses.updateStation(
      user.companyId,
      warehouseId,
      stationId,
      user.sub,
      dto,
      req.ip,
    );
  }

  @Post(':warehouseId/stations/:stationId/heartbeat')
  heartbeat(
    @CurrentUser() user: AuthenticatedUser,
    @Param('warehouseId') warehouseId: string,
    @Param('stationId') stationId: string,
  ) {
    return this.warehouses.heartbeat(user.companyId, warehouseId, stationId);
  }
}
