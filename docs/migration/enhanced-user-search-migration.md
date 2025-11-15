# 用户搜索功能升级迁移指南

## 概述

本指南帮助你从基础的 `UserSelector` 组件升级到增强的 `EnhancedUserSelector` 组件，并集成新的后端API。

## 迁移步骤

### 1. 后端API实现

#### 优先级1：必须实现
```rust
// 1. search_users - 用户搜索 (高优先级)
#[tauri::command]
async fn search_users(query: UserSearchQuery) -> Result<UserSearchResponse> {
    // 实现用户搜索逻辑
}

// 2. get_user - 根据ID获取用户 (高优先级)
#[tauri::command] 
async fn get_user(serial_num: String) -> Result<User> {
    // 实现根据ID获取用户
}
```

#### 优先级2：建议实现
```rust
// 3. list_recent_users - 最近活跃用户 (中优先级)
#[tauri::command]
async fn list_recent_users(limit: Option<u32>, days_back: Option<u32>) -> Result<Vec<User>> {
    // 实现最近用户列表
}

// 4. suggest_users - 用户推荐 (低优先级)
#[tauri::command]
async fn suggest_users(current_user_id: String, limit: Option<u32>) -> Result<Vec<User>> {
    // 实现用户推荐
}
```

### 2. 前端组件升级

#### 方案A：渐进式升级 (推荐)

保留现有组件，逐步替换：

```vue
<!-- 旧的使用方式 -->
<UserSelector 
  placeholder="输入完整邮箱地址搜索用户"
  @select="handleUserSelect"
  @clear="handleUserClear"
/>

<!-- 新的使用方式 -->
<EnhancedUserSelector 
  placeholder="搜索用户"
  :show-recent-users="true"
  :show-search-history="true"
  @select="handleUserSelect"
  @clear="handleUserClear"
/>
```

#### 方案B：完全替换

直接用增强版本替换所有现有使用：

```typescript
// 1. 更新导入
- import UserSelector from '@/components/ui/UserSelector.vue';
+ import EnhancedUserSelector from '@/components/ui/EnhancedUserSelector.vue';

// 2. 更新组件注册
components: {
-  UserSelector,
+  UserSelector: EnhancedUserSelector,
}
```

### 3. useUserSearch 升级

#### 现有代码无需修改

新版本的 `useUserSearch` 完全向后兼容，现有代码无需修改即可获得以下增强功能：

- ✅ **自动缓存** - 5分钟搜索结果缓存
- ✅ **搜索历史** - 自动保存最近10次搜索
- ✅ **最近用户** - 显示最近活跃用户
- ✅ **渐进式增强** - API不存在时自动降级

#### 可选：使用新功能

```typescript
const {
  // 现有功能（保持不变）
  searchQuery,
  users,
  loading,
  error,
  selectedUser,
  searchUsers,
  // 新增功能
  recentUsers,
  searchHistory,
  loadRecentUsers,
  clearSearchCache,
  clearSearchHistory,
} = useUserSearch();

// 组件挂载时加载最近用户
onMounted(() => {
  loadRecentUsers();
});
```

### 4. 用户偏好管理

#### 集成偏好管理 (可选)

```typescript
import { userPreferences } from '@/utils/userPreferences';

// 获取偏好设置
const preferences = userPreferences.getPreferences();

// 更新设置
userPreferences.updatePreferences({
  maxHistoryItems: 15,
  cacheEnabled: true,
});

// 监听用户选择
function handleUserSelect(user: User) {
  userPreferences.addRecentSelection(user.serialNum);
  emit('select', user);
}
```

## 兼容性保证

### 向后兼容性

1. **API兼容** - 所有现有API调用保持不变
2. **组件接口** - Props和Events保持一致
3. **渐进式增强** - 新功能在后端API缺失时自动禁用

### 错误处理

新版本提供更好的错误处理：

```typescript
// 自动降级策略
if (newAPIExists) {
  // 使用增强搜索
  result = await invokeCommand('search_users', params);
} else {
  // 降级到基础搜索
  result = await invokeCommand('get_user_with_email', params);
}
```

## 性能优化

### 搜索缓存

```typescript
// 配置缓存策略
userPreferences.updatePreferences({
  cacheEnabled: true,
  cacheDuration: 10 * 60 * 1000, // 10分钟
});
```

### 防抖优化

```typescript
// 自定义防抖时间
const debouncedSearch = debounce(searchUsers, 500); // 500ms
```

### 预加载策略

```typescript
// 在适当时机预加载
onMounted(async () => {
  // 预加载最近用户
  await loadRecentUsers();
  
  // 预加载搜索历史对应的用户信息
  const history = userPreferences.getSearchHistory();
  if (history.length > 0) {
    // 可以考虑预加载最近搜索的用户
  }
});
```

## 测试策略

### 单元测试

```typescript
// 测试搜索功能
describe('Enhanced User Search', () => {
  test('should cache search results', async () => {
    const { searchUsers, users } = useUserSearch();
    
    // 第一次搜索
    await searchUsers('test@example.com');
    expect(users.value).toHaveLength(1);
    
    // 第二次搜索（应使用缓存）
    await searchUsers('test@example.com');
    // 验证缓存使用
  });
  
  test('should handle API fallback', async () => {
    // 模拟新API不存在
    mockInvokeCommand.mockRejectedValueOnce(new Error('Command not found'));
    
    const { searchUsers } = useUserSearch();
    await searchUsers('test@example.com');
    
    // 验证降级到旧API
    expect(mockInvokeCommand).toHaveBeenCalledWith('get_user_with_email', expect.any(Object));
  });
});
```

### 集成测试

```typescript
// 测试组件集成
describe('EnhancedUserSelector Integration', () => {
  test('should show search history', async () => {
    userPreferences.addSearchHistory('previous search');
    
    const wrapper = mount(EnhancedUserSelector);
    await wrapper.find('input').trigger('focus');
    
    expect(wrapper.text()).toContain('previous search');
  });
});
```

## 监控和分析

### 性能监控

```typescript
// 添加性能监控
const performanceTracker = {
  trackSearchTime: (query: string, duration: number) => {
    // 发送到分析服务
    console.log(`Search "${query}" took ${duration}ms`);
  },
  
  trackCacheHit: (query: string) => {
    console.log(`Cache hit for "${query}"`);
  }
};
```

### 用户行为分析

```typescript
// 分析搜索模式
const analytics = {
  mostSearchedQueries: () => {
    const history = userPreferences.getSearchHistory();
    // 分析最常搜索的内容
  },
  
  searchSuccessRate: () => {
    // 分析搜索成功率
  }
};
```

## 部署检查清单

### 部署前检查

- [ ] 后端API实现完成
- [ ] 前端组件测试通过
- [ ] 缓存机制验证
- [ ] 降级策略测试
- [ ] 性能基准测试

### 部署后监控

- [ ] API响应时间监控
- [ ] 缓存命中率统计
- [ ] 用户搜索成功率
- [ ] 错误率监控

## 故障排除

### 常见问题

1. **搜索无结果**
   - 检查后端API是否正确实现
   - 验证数据库索引
   - 确认搜索参数格式

2. **缓存问题**
   - 清除本地存储
   - 检查缓存时间配置
   - 验证缓存键生成

3. **性能问题**
   - 调整防抖时间
   - 优化搜索查询
   - 检查数据库性能

### 调试工具

```typescript
// 启用调试模式
window.enableUserSearchDebug = true;

// 查看缓存状态
console.log('Search cache:', searchCache);
console.log('User preferences:', userPreferences.getPreferences());
```
