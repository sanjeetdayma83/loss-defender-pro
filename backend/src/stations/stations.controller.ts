import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { StationsService } from './stations.service';

class CreateStationDto {
  @IsUUID() warehouseId: string;
  @IsString() @MinLength(2) @MaxLength(80) stationName: string;
  @IsString() @MinLength(1) @MaxLength(40) stationId: string;
  @IsOptional() @IsString() status?: string;
}

class UpdateStationDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80) stationName?: string;
  @IsOptional() @IsString() status?: string;
}

@ApiTags('stations')
@ApiBearerAuth()
@Controller('stations')
export class StationsController {
  constructor(private readonly stations: StationsService) {}

  @Get()
  list(@CurrentUser() u: AuthenticatedUser, @Query('warehouseId') warehouseId?: string) {
    return this.stations.list(u.companyId, warehouseId);
  }

  @Post()
  create(@CurrentUser() u: AuthenticatedUser, @Body() dto: CreateStationDto) {
    return this.stations.create(u.companyId, dto);
  }

  @Patch(':id')
  update(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateStationDto) {
    return this.stations.update(u.companyId, id, dto);
  }
}