# 费用分摊功能 - 前端集成指南

## ✅ 已完成的前端更新

### 1. TransactionModal.vue 更新

#### splitConfig 类型定义
```typescript
const splitConfig = ref<{
  enabled: boolean;
  splitType?: string;
  members?: Array<{
    memberSerialNum: string;
    memberName: string;
    amount: number;
    percentage?: number;  // 新增：按比例时使用
    weight?: number;      // 新增：按权重时使用
  }>;
}>({
  enabled: false,
});
```

#### 提交数据格式
```typescript
function emitTransaction(amount: number) {
  const transaction: TransactionCreate = {
    // ... 其他字段
    
    // 移除了 splitMembers，改用 splitConfig
    splitConfig: splitConfig.value.enabled && 
                 splitConfig.value.members && 
                 splitConfig.value.members.length > 0
      ? {
          splitType: splitConfig.value.splitType || 'EQUAL',
          members: splitConfig.value.members,
        }
      : undefined,
  };
}
```

#### 编辑时恢复配置
```typescript
// 在 onMounted 中
if (props.transaction.splitConfig && props.transaction.splitConfig.enabled) {
  splitConfig.value = {
    enabled: true,
    splitType: props.transaction.splitConfig.splitType,
    members: props.transaction.splitConfig.members || [],
  };
} else {
  splitConfig.value = {
    enabled: false,
  };
}
```

### 2. TransactionSplitSection.vue 更新

#### Props 定义
```typescript
interface Props {
  transactionAmount: number;
  ledgerSerialNum?: string;
  selectedMembers: string[];
  availableMembers?: any[];
  initialConfig?: {  // 新增：用于编辑时恢复配置
    enabled: boolean;
    splitType?: string;
    members?: Array<{
      memberSerialNum: string;
      memberName: string;
      amount: number;
      percentage?: number;
      weight?: number;
    }>;
  };
}
```

#### splitPreview 类型更新
```typescript
const splitPreview = computed(() => {
  // ...
  const results: Array<{ 
    memberSerialNum: string; 
    memberName: string; 
    amount: number;
    percentage?: number;  // 新增
    weight?: number;      // 新增
  }> = [];
  
  // 在 PERCENTAGE 模式下
  results.push({
    memberSerialNum: memberId,
    memberName: member?.name || 'Unknown',
    amount: (props.transactionAmount * percentage) / 100,
    percentage, // 包含百分比
  });
  
  // 在 WEIGHTED 模式下
  results.push({
    memberSerialNum: memberId,
    memberName: member?.name || 'Unknown',
    amount: (props.transactionAmount * weight) / totalWeight,
    weight, // 包含权重
  });
});
```

#### 配置恢复逻辑
```typescript
// 监听 initialConfig，用于编辑时恢复配置
watch(() => props.initialConfig, (config) => {
  if (config && config.enabled) {
    enableSplit.value = true;
    splitConfig.splitType = config.splitType as SplitRuleType || 'EQUAL';
    
    // 恢复分摊参数
    if (config.members) {
      config.members.forEach(member => {
        splitConfig.splitParams[member.memberSerialNum] = {
          amount: member.amount,
          percentage: member.percentage,
          weight: member.weight,
        };
      });
    }
  }
}, { immediate: true });
```

#### 组件使用
```vue
<TransactionSplitSection
  :transaction-amount="form.amount"
  :ledger-serial-num="selectedLedgers[0]"
  :selected-members="selectedMembers"
  :available-members="availableMembers"
  :initial-config="splitConfig"
  @update:split-config="handleSplitConfigUpdate"
/>
```

## 🔄 数据流程

### 创建新交易

```
用户操作
    ↓
选择分摊成员 → selectedMembers
    ↓
启用分摊 → enableSplit = true
    ↓
选择分摊类型 → splitType (EQUAL/PERCENTAGE/FIXED_AMOUNT/WEIGHTED)
    ↓
输入参数 → splitParams { percentage/amount/weight }
    ↓
计算预览 → splitPreview (computed)
    ↓
通知父组件 → emit('update:split-config', { enabled, splitType, members })
    ↓
父组件保存 → splitConfig.value = config
    ↓
提交表单 → emitTransaction()
    ↓
构造请求 → {
  splitConfig: {
    splitType: "PERCENTAGE",
    members: [
      { memberSerialNum, memberName, amount, percentage },
      ...
    ]
  }
}
    ↓
发送到后端 → emit('save', transaction)
```

### 编辑现有交易

```
加载交易
    ↓
props.transaction.splitConfig 存在
    ↓
onMounted 中恢复 → splitConfig.value = {
  enabled: true,
  splitType: ...,
  members: [...]
}
    ↓
传递给子组件 → :initial-config="splitConfig"
    ↓
子组件 watch initialConfig
    ↓
恢复状态 → enableSplit.value = true
           splitConfig.splitType = ...
           splitConfig.splitParams = {...}
    ↓
显示配置 → 用户看到之前的分摊设置
    ↓
修改配置 → 用户可以调整参数
    ↓
保存更新 → 同创建流程
```

## 📝 数据格式示例

### 前端发送到后端

#### 按比例分摊
```json
{
  "splitConfig": {
    "splitType": "PERCENTAGE",
    "members": [
      {
        "memberSerialNum": "member-uuid-1",
        "memberName": "Alice",
        "amount": 60.00,
        "percentage": 60.0
      },
      {
        "memberSerialNum": "member-uuid-2",
        "memberName": "Bob",
        "amount": 40.00,
        "percentage": 40.0
      }
    ]
  }
}
```

#### 固定金额分摊
```json
{
  "splitConfig": {
    "splitType": "FIXED_AMOUNT",
    "members": [
      {
        "memberSerialNum": "member-uuid-1",
        "memberName": "Alice",
        "amount": 60.00
      },
      {
        "memberSerialNum": "member-uuid-2",
        "memberName": "Bob",
        "amount": 40.00
      }
    ]
  }
}
```

#### 按权重分摊
```json
{
  "splitConfig": {
    "splitType": "WEIGHTED",
    "members": [
      {
        "memberSerialNum": "member-uuid-1",
        "memberName": "Alice",
        "amount": 66.67,
        "weight": 2
      },
      {
        "memberSerialNum": "member-uuid-2",
        "memberName": "Bob",
        "amount": 33.33,
        "weight": 1
      }
    ]
  }
}
```

### 后端返回给前端

```json
{
  "serialNum": "transaction-uuid",
  "amount": 100.00,
  "splitConfig": {
    "enabled": true,
    "splitType": "PERCENTAGE",
    "members": [
      {
        "memberSerialNum": "member-uuid-1",
        "memberName": "Alice",
        "amount": 60.00,
        "percentage": 60.0,
        "weight": null,
        "isPaid": false,
        "paidAt": null
      },
      {
        "memberSerialNum": "member-uuid-2",
        "memberName": "Bob",
        "amount": 40.00,
        "percentage": 40.0,
        "weight": null,
        "isPaid": false,
        "paidAt": null
      }
    ]
  }
}
```

## 🧪 测试指南

### 测试场景 1：创建带分摊的交易

**步骤：**
1. 打开交易创建表单
2. 选择家庭账本
3. 选择分摊成员（至少2人）
4. 启用费用分摊
5. 选择分摊类型（如"按比例"）
6. 输入每个成员的比例
7. 查看分摊预览
8. 保存交易

**预期结果：**
- 分摊预览显示正确
- 保存成功
- 后端创建了 split_records 和 split_record_details 记录

**验证：**
```sql
SELECT * FROM split_records WHERE transaction_serial_num = ?;
SELECT * FROM split_record_details WHERE split_record_serial_num = ?;
```

### 测试场景 2：查看带分摊的交易

**步骤：**
1. 打开一个已有分摊的交易
2. 查看分摊配置

**预期结果：**
- "启用费用分摊"开关已开启
- 显示正确的分摊类型
- 显示每个成员的分摊参数
- 分摊预览正确

### 测试场景 3：编辑分摊配置

**步骤：**
1. 打开一个已有分摊的交易
2. 修改分摊类型或参数
3. 保存

**预期结果：**
- 配置更新成功
- 数据库中的 split_records 更新

### 测试场景 4：不同分摊类型

**测试各种分摊类型：**
1. **均摊** - 自动平均分配
2. **按比例** - 验证总和为100%
3. **固定金额** - 验证总和等于交易金额
4. **按权重** - 验证权重计算正确

### 测试场景 5：边界情况

**测试：**
- 只有1个成员
- 超过10个成员
- 分摊金额为0
- 修改交易金额后重新计算
- 添加/删除成员

## ⚠️ 注意事项

### 1. 数据验证

前端应该验证：
- ✅ 分摊比例总和 = 100%（按比例模式）
- ✅ 分摊金额总和 = 交易金额（固定金额模式）
- ✅ 至少有一个成员
- ✅ 每个成员的值 > 0

### 2. 用户体验

- 实时显示分摊预览
- 自动计算剩余金额/比例
- 提供"平均分配"快捷按钮
- 清晰的错误提示

### 3. 性能优化

- 使用 computed 而不是 method 计算预览
- 避免不必要的 watch 触发
- 合理使用 deep watch

### 4. 向后兼容

- 旧交易没有 splitConfig，应该正常显示
- 编辑旧交易时不应自动启用分摊

## 🐛 故障排查

### Q1: 编辑时分摊配置没有显示？

**检查：**
```typescript
// 1. 后端是否返回 splitConfig
console.log('Transaction:', props.transaction);
console.log('Split Config:', props.transaction.splitConfig);

// 2. splitConfig 值是否正确
console.log('Local splitConfig:', splitConfig.value);

// 3. initialConfig 是否传递
console.log('Initial Config:', props.initialConfig);
```

### Q2: 分摊预览计算错误？

**检查：**
```typescript
// 1. splitParams 是否正确
console.log('Split Params:', splitConfig.splitParams);

// 2. 检查计算逻辑
console.log('Split Preview:', splitPreview.value);
```

### Q3: 保存后数据库没有分摊记录？

**检查：**
```typescript
// 1. splitConfig 是否正确发送
console.log('Submitting:', transaction.splitConfig);

// 2. 后端日志
// 查看是否调用了 create_split_records
```

## 📊 完成清单

- [x] ✅ 更新 TransactionModal.vue splitConfig 类型
- [x] ✅ 移除 splitMembers 处理逻辑
- [x] ✅ 优化 emitTransaction 方法
- [x] ✅ 实现编辑时配置恢复
- [x] ✅ 更新 TransactionSplitSection.vue props
- [x] ✅ 更新 splitPreview 类型
- [x] ✅ 添加 initialConfig 监听器
- [x] ✅ 传递 initial-config 属性
- [ ] ⏳ 测试创建流程
- [ ] ⏳ 测试编辑流程
- [ ] ⏳ 测试各种分摊类型
- [ ] ⏳ 添加数据验证逻辑

## 🎉 总结

前端集成已完成基础功能，主要更新：

1. **数据结构对齐** - 前端数据格式匹配后端 DTO
2. **编辑支持** - 支持查看和修改现有分摊配置
3. **类型安全** - 完整的 TypeScript 类型定义
4. **向后兼容** - 旧数据不受影响

**下一步：**
- 进行完整的功能测试
- 添加前端数据验证
- 优化用户体验
