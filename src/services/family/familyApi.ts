// services/family/familyApi.ts
import type {
  DebtRelation,
  FamilyLedger,
  FamilyLedgerCreate,
  FamilyLedgerStats,
  FamilyLedgerUpdate,
  FamilyMember,
  FamilyMemberCreate,
  FamilyMemberUpdate,
  MemberFinancialStats,
  SettlementRecord,
  SettlementSuggestion,
  SplitRecord,
  SplitRecordCreate,
  SplitRuleConfig,
  SplitRuleConfigCreate,
  SplitRuleConfigUpdate,
} from '@/schema/money';

// 基础API配置
const API_BASE_URL = '/api/family';

// 通用请求函数
async function request<T>(
  endpoint: string,
  options: RequestInit = {},
): Promise<T> {
  const url = `${API_BASE_URL}${endpoint}`;

  const defaultOptions: RequestInit = {
    headers: {
      'Content-Type': 'application/json',
      // TODO: 添加认证头
      // 'Authorization': `Bearer ${getAuthToken()}`,
    },
  };

  const response = await fetch(url, {
    ...defaultOptions,
    ...options,
    headers: {
      ...defaultOptions.headers,
      ...options.headers,
    },
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ message: 'Network error' }));
    throw new Error(error.message || `HTTP ${response.status}`);
  }

  return response.json();
}

// 家庭账本API
export const FamilyLedgerApi = {
  // 获取账本列表
  async listLedgers(): Promise<FamilyLedger[]> {
    return request<FamilyLedger[]>('/ledgers');
  },

  // 获取账本详情
  async getLedger(serialNum: string): Promise<FamilyLedger> {
    return request<FamilyLedger>(`/ledgers/${serialNum}`);
  },

  // 创建账本
  async createLedger(data: FamilyLedgerCreate): Promise<FamilyLedger> {
    return request<FamilyLedger>('/ledgers', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  // 更新账本
  async updateLedger(serialNum: string, data: FamilyLedgerUpdate): Promise<FamilyLedger> {
    return request<FamilyLedger>(`/ledgers/${serialNum}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  },

  // 删除账本
  async deleteLedger(serialNum: string): Promise<void> {
    return request<void>(`/ledgers/${serialNum}`, {
      method: 'DELETE',
    });
  },

  // 获取账本统计
  async getLedgerStats(serialNum: string): Promise<FamilyLedgerStats> {
    return request<FamilyLedgerStats>(`/ledgers/${serialNum}/stats`);
  },
};

// 家庭成员API
export const FamilyMemberApi = {
  // 获取成员列表
  async listMembers(ledgerSerialNum?: string): Promise<FamilyMember[]> {
    const params = ledgerSerialNum ? `?ledgerSerialNum=${ledgerSerialNum}` : '';
    return request<FamilyMember[]>(`/members${params}`);
  },

  // 获取成员详情
  async getMember(serialNum: string): Promise<FamilyMember> {
    return request<FamilyMember>(`/members/${serialNum}`);
  },

  // 创建成员
  async createMember(data: FamilyMemberCreate): Promise<FamilyMember> {
    return request<FamilyMember>('/members', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  // 更新成员
  async updateMember(serialNum: string, data: FamilyMemberUpdate): Promise<FamilyMember> {
    return request<FamilyMember>(`/members/${serialNum}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  },

  // 删除成员
  async deleteMember(serialNum: string): Promise<void> {
    return request<void>(`/members/${serialNum}`, {
      method: 'DELETE',
    });
  },

  // 获取成员统计
  async getMemberStats(serialNum: string): Promise<MemberFinancialStats> {
    return request<MemberFinancialStats>(`/members/${serialNum}/stats`);
  },

  // 邀请用户
  async inviteUser(email: string, role: string, ledgerSerialNum: string): Promise<void> {
    return request<void>('/members/invite', {
      method: 'POST',
      body: JSON.stringify({ email, role, ledgerSerialNum }),
    });
  },
};

// 分摊规则API
export const SplitRuleApi = {
  // 获取分摊规则列表
  async listSplitRules(ledgerSerialNum?: string): Promise<SplitRuleConfig[]> {
    const params = ledgerSerialNum ? `?ledgerSerialNum=${ledgerSerialNum}` : '';
    return request<SplitRuleConfig[]>(`/split-rules${params}`);
  },

  // 获取分摊规则详情
  async getSplitRule(serialNum: string): Promise<SplitRuleConfig> {
    return request<SplitRuleConfig>(`/split-rules/${serialNum}`);
  },

  // 创建分摊规则
  async createSplitRule(data: SplitRuleConfigCreate): Promise<SplitRuleConfig> {
    return request<SplitRuleConfig>('/split-rules', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  // 更新分摊规则
  async updateSplitRule(serialNum: string, data: SplitRuleConfigUpdate): Promise<SplitRuleConfig> {
    return request<SplitRuleConfig>(`/split-rules/${serialNum}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  },

  // 删除分摊规则
  async deleteSplitRule(serialNum: string): Promise<void> {
    return request<void>(`/split-rules/${serialNum}`, {
      method: 'DELETE',
    });
  },

  // 获取分摊模板
  async getTemplates(): Promise<SplitRuleConfig[]> {
    return request<SplitRuleConfig[]>('/split-rules/templates');
  },
};

// 分摊记录API
export const SplitRecordApi = {
  // 获取分摊记录列表
  async listSplitRecords(ledgerSerialNum?: string): Promise<SplitRecord[]> {
    const params = ledgerSerialNum ? `?ledgerSerialNum=${ledgerSerialNum}` : '';
    return request<SplitRecord[]>(`/split-records${params}`);
  },

  // 创建分摊记录
  async createSplitRecord(data: SplitRecordCreate): Promise<SplitRecord> {
    return request<SplitRecord>('/split-records', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  // 标记分摊为已支付
  async markAsPaid(recordSerialNum: string, memberSerialNum: string): Promise<void> {
    return request<void>(`/split-records/${recordSerialNum}/pay`, {
      method: 'POST',
      body: JSON.stringify({ memberSerialNum }),
    });
  },
};

// 债务关系API
export const DebtRelationApi = {
  // 获取债务关系列表
  async listDebtRelations(ledgerSerialNum: string): Promise<DebtRelation[]> {
    return request<DebtRelation[]>(`/debt-relations?ledgerSerialNum=${ledgerSerialNum}`);
  },

  // 获取成员债务
  async getMemberDebts(memberSerialNum: string): Promise<DebtRelation[]> {
    return request<DebtRelation[]>(`/debt-relations/member/${memberSerialNum}`);
  },
};

// 结算API
export const SettlementApi = {
  // 获取结算建议
  async getSettlementSuggestions(ledgerSerialNum: string): Promise<SettlementSuggestion[]> {
    return request<SettlementSuggestion[]>(`/settlement/suggestions?ledgerSerialNum=${ledgerSerialNum}`);
  },

  // 获取结算记录
  async listSettlementRecords(ledgerSerialNum: string): Promise<SettlementRecord[]> {
    return request<SettlementRecord[]>(`/settlement/records?ledgerSerialNum=${ledgerSerialNum}`);
  },

  // 执行结算
  async executeSettlement(ledgerSerialNum: string, suggestions: SettlementSuggestion[]): Promise<SettlementRecord> {
    return request<SettlementRecord>('/settlement/execute', {
      method: 'POST',
      body: JSON.stringify({ ledgerSerialNum, suggestions }),
    });
  },
};

// 导出API
export const ExportApi = {
  // 导出统计数据
  async exportStats(
    ledgerSerialNum: string,
    format: 'csv' | 'excel' | 'pdf',
    options?: {
      startDate?: string;
      endDate?: string;
      includeMembers?: boolean;
      includeTransactions?: boolean;
    },
  ): Promise<Blob> {
    const params = new URLSearchParams();
    params.append('ledgerSerialNum', ledgerSerialNum);
    params.append('format', format);

    if (options) {
      Object.entries(options).forEach(([key, value]) => {
        if (value !== undefined) {
          params.append(key, String(value));
        }
      });
    }

    const response = await fetch(`${API_BASE_URL}/export/stats?${params}`, {
      headers: {
        // TODO: 添加认证头
        // 'Authorization': `Bearer ${getAuthToken()}`,
      },
    });

    if (!response.ok) {
      throw new Error(`Export failed: ${response.statusText}`);
    }

    return response.blob();
  },

  // 导出分摊记录
  async exportSplitRecords(
    ledgerSerialNum: string,
    format: 'csv' | 'excel',
  ): Promise<Blob> {
    const params = new URLSearchParams({ ledgerSerialNum, format });

    const response = await fetch(`${API_BASE_URL}/export/split-records?${params}`, {
      headers: {
        // TODO: 添加认证头
        // 'Authorization': `Bearer ${getAuthToken()}`,
      },
    });

    if (!response.ok) {
      throw new Error(`Export failed: ${response.statusText}`);
    }

    return response.blob();
  },
};

// 统一导出
export const FamilyApi = {
  ledgers: FamilyLedgerApi,
  members: FamilyMemberApi,
  splitRules: SplitRuleApi,
  splitRecords: SplitRecordApi,
  debtRelations: DebtRelationApi,
  settlement: SettlementApi,
  export: ExportApi,
};
