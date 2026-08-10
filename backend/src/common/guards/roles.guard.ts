import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core'; import { Role } from '@prisma/client'; import { PrismaService } from '../../prisma/prisma.service'; import { ROLES_KEY } from '../decorators/roles.decorator'; import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
@Injectable()
export class RolesGuard implements CanActivate {
 constructor(private readonly reflector:Reflector,private readonly prisma:PrismaService){}
 async canActivate(context:ExecutionContext):Promise<boolean>{const isPublic=this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY,[context.getHandler(),context.getClass()]);if(isPublic)return true;const req=context.switchToHttp().getRequest();const user=req.user; if(!user?.sub)throw new ForbiddenException('Missing authenticated user');const dbUser=await this.prisma.user.findFirst({where:{id:user.sub,companyId:user.companyId}});if(!dbUser||dbUser.status!=='active')throw new ForbiddenException('User is not active');user.role=dbUser.role;const required=this.reflector.getAllAndOverride<Role[]>(ROLES_KEY,[context.getHandler(),context.getClass()]);if(!required||required.length===0)return true;if(dbUser.role===Role.super_admin)return true;if(!required.includes(dbUser.role))throw new ForbiddenException(`Requires one of: ${required.join(', ')}`);return true;}
}
