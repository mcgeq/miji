/* eslint-disable no-console */
/**
 * 分摊功能 Mock Service
 *
 * 用途：
 * 1. 快速验证前端UI功能
 * 2. 前端开发时不依赖后端
 * 3. 演示和原型展示
 *
 * 使用方法：
 * 1. 临时使用：将此文件改名为 split.ts
 * 2. 或在组件中导入：import { mockSplitService as splitService } from '@/services/money/split.mock'
 * 3. 后端实现后，替换为真实Service
 */

export interface SplitRuleType {
  type: 'EQUAL' | 'PERCENTAGE' | 'FIXED_AMOUNT' | 'WEIGHTED';
}

export interface SplitMember {
  member_serial_num: string;
  member_name: string;
  amount: number;
  percentage?: number;
  weight?: number;
  is_paid: boolean;
  paid_at?: string;
}

export interface SplitTemplateCreateRequest {
  name: string;
  description?: string;
  rule_type: string;
  is_default?: boolean;
  family_ledger_serial_num?: string;
  participants?: Array<{
    member_serial_num: string;
    percentage?: number;
    amount?: number;
    weight?: number;
  }>;
}

export interface SplitRecordCreateRequest {
  transaction_serial_num: string;
  family_ledger_serial_num: string;
  rule_type: string;
  total_amount: number;
  split_details: SplitMember[];
}

export interface SplitRecordListRequest {
  family_ledger_serial_num?: string;
  member_serial_num?: string;
  rule_type?: string;
  status?: 'all' | 'pending' | 'completed';
  start_date?: string;
  end_date?: string;
  min_amount?: number;
  max_amount?: number;
  page?: number;
  page_size?: number;
}

// Mock 数据
const mockTemplates: Array<{
  serial_num: string;
  name: string;
  description: string;
  rule_type: string;
  is_default: boolean;
  is_template: boolean;
  family_ledger_serial_num?: string;
  participants: Array<{
    member_serial_num: string;
    percentage?: number;
    amount?: number;
    weight?: number;
  }>;
  created_at: string;
}> = [
  {
    serial_num: 'ST001',
    name: '家庭均摊',
    description: '所有成员平均分摊',
    rule_type: 'EQUAL',
    is_default: true,
    is_template: true,
    participants: [],
    created_at: '2025-11-16T10:00:00Z',
  },
  {
    serial_num: 'ST002',
    name: '按收入比例',
    description: '按照收入比例分摊',
    rule_type: 'PERCENTAGE',
    is_default: false,
    is_template: true,
    participants: [],
    created_at: '2025-11-16T10:00:00Z',
  },
];

const mockRecords: any[] = [];

// Mock Service 实现
export const mockSplitService = {
  /**
   * 创建分摊模板
   */
  async createTemplate(data: SplitTemplateCreateRequest) {
    console.log('📝 Mock: 创建分摊模板', data);

    const template = {
      serial_num: `ST${Date.now()}`,
      name: data.name,
      description: data.description || '',
      rule_type: data.rule_type,
      is_default: data.is_default || false,
      is_template: true,
      family_ledger_serial_num: data.family_ledger_serial_num,
      participants: data.participants || [],
      created_at: new Date().toISOString(),
    };

    mockTemplates.push(template);

    return {
      success: true,
      data: template,
    };
  },

  /**
   * 获取分摊模板列表
   */
  async listTemplates(params: any = {}) {
    console.log('📋 Mock: 获取模板列表', params);

    let filtered = [...mockTemplates];

    // 模拟筛选
    if (params.rule_type) {
      filtered = filtered.filter(t => t.rule_type === params.rule_type);
    }

    return {
      templates: filtered,
      total: filtered.length,
      page: params.page || 1,
      page_size: params.page_size || 20,
    };
  },

  /**
   * 更新分摊模板
   */
  async updateTemplate(serialNum: string, data: any) {
    console.log('✏️ Mock: 更新模板', serialNum, data);

    const index = mockTemplates.findIndex(t => t.serial_num === serialNum);
    if (index >= 0) {
      mockTemplates[index] = { ...mockTemplates[index], ...data };
      return { success: true, data: mockTemplates[index] };
    }

    return { success: false, message: '模板不存在' };
  },

  /**
   * 删除分摊模板
   */
  async deleteTemplate(serialNum: string) {
    console.log('🗑️ Mock: 删除模板', serialNum);

    const index = mockTemplates.findIndex(t => t.serial_num === serialNum);
    if (index >= 0) {
      mockTemplates.splice(index, 1);
      return { success: true, message: '删除成功' };
    }

    return { success: false, message: '模板不存在' };
  },

  /**
   * 创建分摊记录
   */
  async createRecord(data: SplitRecordCreateRequest) {
    console.log('📝 Mock: 创建分摊记录', data);

    const record = {
      serial_num: `SR${Date.now()}`,
      ...data,
      created_at: new Date().toISOString(),
    };

    mockRecords.push(record);

    return {
      success: true,
      data: record,
    };
  },

  /**
   * 查询分摊记录列表
   */
  async listRecords(params: SplitRecordListRequest = {}) {
    console.log('📋 Mock: 查询分摊记录', params);

    let filtered = [...mockRecords];

    // 模拟筛选
    if (params.family_ledger_serial_num) {
      filtered = filtered.filter(r =>
        r.family_ledger_serial_num === params.family_ledger_serial_num,
      );
    }

    if (params.rule_type) {
      filtered = filtered.filter(r => r.rule_type === params.rule_type);
    }

    if (params.status && params.status !== 'all') {
      filtered = filtered.filter(r => {
        const allPaid = r.split_details.every((d: any) => d.is_paid);
        return params.status === 'completed' ? allPaid : !allPaid;
      });
    }

    // 模拟统计
    const statistics = {
      total_records: filtered.length,
      completed_records: filtered.filter(r =>
        r.split_details.every((d: any) => d.is_paid),
      ).length,
      pending_records: filtered.filter(r =>
        !r.split_details.every((d: any) => d.is_paid),
      ).length,
      total_amount: filtered.reduce((sum, r) => sum + r.total_amount, 0),
      paid_amount: 0,
      unpaid_amount: 0,
    };

    return {
      records: filtered,
      total: filtered.length,
      page: params.page || 1,
      page_size: params.page_size || 20,
      statistics,
    };
  },

  /**
   * 获取分摊记录详情
   */
  async getRecordDetail(serialNum: string) {
    console.log('🔍 Mock: 获取分摊详情', serialNum);

    const record = mockRecords.find(r => r.serial_num === serialNum);

    if (record) {
      return {
        success: true,
        data: {
          ...record,
          statistics: {
            total_members: record.split_details.length,
            paid_members: record.split_details.filter((d: any) => d.is_paid).length,
            unpaid_members: record.split_details.filter((d: any) => !d.is_paid).length,
            paid_amount: record.split_details
              .filter((d: any) => d.is_paid)
              .reduce((sum: number, d: any) => sum + d.amount, 0),
            unpaid_amount: record.split_details
              .filter((d: any) => !d.is_paid)
              .reduce((sum: number, d: any) => sum + d.amount, 0),
            paid_percentage: 0,
          },
        },
      };
    }

    return { success: false, message: '记录不存在' };
  },

  /**
   * 更新支付状态
   */
  async updateStatus(data: {
    serial_num: string;
    member_serial_num: string;
    is_paid: boolean;
    paid_at?: string;
  }) {
    console.log('✅ Mock: 更新支付状态', data);

    const record = mockRecords.find(r => r.serial_num === data.serial_num);

    if (record) {
      const detail = record.split_details.find(
        (d: any) => d.member_serial_num === data.member_serial_num,
      );

      if (detail) {
        detail.is_paid = data.is_paid;
        detail.paid_at = data.is_paid ? (data.paid_at || new Date().toISOString()) : undefined;

        return {
          success: true,
          message: '更新成功',
          updated_detail: detail,
        };
      }
    }

    return { success: false, message: '记录不存在' };
  },
};

// 默认导出 Mock Service
// 注意：后端实现后，应该替换为真实的 Service
export const splitService = mockSplitService;

/**
 * 使用说明：
 *
 * 1. 在组件中导入：
 *    import { splitService } from '@/services/money/split.mock';
 *
 * 2. 调用示例：
 *    const result = await splitService.createTemplate({
 *      name: '测试模板',
 *      rule_type: 'EQUAL',
 *    });
 *
 * 3. 后端实现后，修改导入路径：
 *    import { splitService } from '@/services/money/split';
 */
