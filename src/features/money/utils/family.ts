import type { MemberUserRole } from '@/schema/userRole';

export function getRoleName(role: MemberUserRole): string {
  const roleNames: Record<MemberUserRole, string> = {
    Owner: '所有者',
    Admin: '管理员',
    Member: '成员',
    Viewer: '查看',
  };
  return roleNames[role] || '未知';
}
