import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { TenantGuard } from '../guards/tenant.guard';
import { CurrentUser, AuthenticatedUser } from '../decorators/current-user.decorator';
import { permissionsFor, ROUTE_PERMISSION } from './permissions';
import { featuresForPlan, limitsForCompanyPlan } from './plan-features';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('rbac')
@UseGuards(JwtAuthGuard, TenantGuard)
export class RbacController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('permissions')
  async mine(@CurrentUser() u: AuthenticatedUser) {
    const role = ((u as any).role || 'packing_operator') as string;
    const company = await this.prisma.company.findFirst({ where: { id: u.companyId } });
    const planId = ((company as any)?.plan || 'starter') as string;
    const limits = limitsForCompanyPlan(planId);
    const permissions = permissionsFor(role);

    // plan may strip advanced perms for non-enterprise
    const planFeatures = featuresForPlan(planId);
    const effective = permissions.filter((p) => {
      if (p.startsWith('claim') || p.startsWith('return')) {
        return planFeatures.includes('claims_returns') || planId === 'starter' || planId === 'growth' || planId === 'enterprise';
      }
      if (p === 'analytics.read' && planId === 'starter') return true; // basic OK
      if (p === 'billing.manage') return ['owner', 'admin'].includes(role);
      return true;
    });

    // starter: claims allowed in product; growth+ richer — keep claims for all paid for ops
    return {
      role,
      plan: planId,
      permissions: effective.length ? effective : permissions,
      features: planFeatures,
      limits,
      routes: ROUTE_PERMISSION,
      navAllowed: Object.entries(ROUTE_PERMISSION)
        .filter(([, perm]) => (effective.length ? effective : permissions).includes(perm))
        .map(([path]) => path),
    };
  }
}
