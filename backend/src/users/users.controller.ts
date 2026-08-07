import { Controller, Get, Post, Patch, Body, Param, Req } from '@nestjs/common';
import { UsersService } from './users.service';
import { InviteUserDto, UpdateUserDto } from './dto/user.dto';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { Request } from 'express';

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @Roles(Role.owner, Role.manager, Role.supervisor, Role.super_admin)
  list(@CurrentUser() user: AuthenticatedUser) {
    return this.users.list(user.companyId);
  }

  @Get('me')
  me(@CurrentUser() user: AuthenticatedUser) {
    return this.users.me(user.sub, user.companyId);
  }

  @Get(':id')
  @Roles(Role.owner, Role.manager, Role.super_admin)
  getOne(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.users.getOne(user.companyId, id);
  }

  @Post('invite')
  @Roles(Role.owner, Role.manager, Role.super_admin)
  invite(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: InviteUserDto,
    @Req() req: Request,
  ) {
    return this.users.invite(user.companyId, user.sub, dto, req.ip);
  }

  @Patch('me')
  updateMe(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateUserDto,
    @Req() req: Request,
  ) {
    // self can only change name/phone
    const safe = { name: dto.name, phone: dto.phone };
    return this.users.update(user.companyId, user.sub, user.sub, safe, req.ip);
  }

  @Patch(':id')
  @Roles(Role.owner, Role.manager, Role.super_admin)
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateUserDto,
    @Req() req: Request,
  ) {
    return this.users.update(user.companyId, id, user.sub, dto, req.ip);
  }
}
