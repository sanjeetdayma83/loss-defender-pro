export type Permission = string;
const MATRIX: Record<string, string[]> = {
  owner: ['order.read','order.write','order.dispatch','scan.execute','recording.execute','evidence.read','claim.manage','return.manage','user.invite','warehouse.manage','settings.manage','analytics.read','billing.manage'],
  admin: ['order.read','order.write','order.dispatch','scan.execute','recording.execute','evidence.read','claim.manage','return.manage','user.invite','warehouse.manage','settings.manage','analytics.read'],
  supervisor: ['order.read','order.write','scan.execute','recording.execute','evidence.read','claim.manage','return.manage','analytics.read'],
  packing_operator: ['order.read','scan.execute','recording.execute','evidence.read'],
};
export function permissionsFor(role: string) {
  return MATRIX[role] || MATRIX.packing_operator;
}
