# 🔔 Alert vs Toast 使用对比指南

## 📊 核心区别

| 特性 | Toast (通知) | Alert (警告) |
|------|-------------|-------------|
| **位置** | 屏幕角落 (右上/右下) | 页面内联 |
| **生命周期** | 临时 (2-3秒自动消失) | 持久 (手动关闭) |
| **使用场景** | 操作反馈、临时通知 | 重要提示、页面级警告 |
| **交互方式** | 被动展示，自动消失 | 主动阅读，需要确认 |
| **信息量** | 简短 (一句话) | 详细 (标题+描述) |
| **打断性** | 低 (不阻塞操作) | 中 (需要注意但不阻塞) |
| **实现方式** | JavaScript API | Vue 组件 |

## 🎯 使用场景详解

### Toast (vue-toastification) - 操作反馈

**适用场景：**
1. ✅ **操作成功反馈**
   ```typescript
   // 保存成功
   toast.success('保存成功')
   
   // 删除成功
   toast.success('删除成功')
   
   // 更新成功
   toast.success('更新完成')
   ```

2. ✅ **快速错误提示**
   ```typescript
   // 网络错误
   toast.error('网络请求失败')
   
   // 验证错误
   toast.error('请填写必填字段')
   
   // 权限错误
   toast.error('没有访问权限')
   ```

3. ✅ **临时信息通知**
   ```typescript
   // 复制成功
   toast.info('已复制到剪贴板')
   
   // 提醒
   toast.warning('会话即将过期')
   ```

**特点：**
- 🔸 自动消失 (2-3秒)
- 🔸 不打断用户操作
- 🔸 屏幕角落显示
- 🔸 支持堆叠显示
- 🔸 简短文本

### Alert 组件 - 页面级提示

**适用场景：**
1. ✅ **页面级重要提示**
   ```vue
   <!-- 系统维护通知 -->
   <Alert
     type="warning"
     title="系统维护通知"
     description="系统将在今晚 22:00 进行维护，预计持续 2 小时"
     closable
   />
   ```

2. ✅ **表单验证错误汇总**
   ```vue
   <!-- 表单错误 -->
   <Alert
     type="error"
     title="表单验证失败"
     description="请检查以下字段：用户名、邮箱、密码"
     closable
   />
   ```

3. ✅ **功能说明/提示**
   ```vue
   <!-- 功能介绍 -->
   <Alert
     type="info"
     title="新功能上线"
     description="我们新增了费用分摊功能，现在可以轻松管理共同支出了！"
     closable
   />
   ```

4. ✅ **状态提醒**
   ```vue
   <!-- 账户状态 -->
   <Alert
     type="success"
     title="账户已验证"
     description="您的账户已通过实名认证，现在可以使用全部功能"
   />
   ```

5. ✅ **上下文相关警告**
   ```vue
   <!-- 数据权限提示 -->
   <Alert
     type="warning"
     title="只读模式"
     description="当前账本处于只读模式，您无法修改数据。请联系管理员获取编辑权限。"
   />
   ```

**特点：**
- 🔸 持久显示 (需手动关闭)
- 🔸 内联在页面内容中
- 🔸 可包含详细信息
- 🔸 可包含链接和操作
- 🔸 提供上下文

## 💡 实际使用示例

### 场景 1: 保存数据

```typescript
// ❌ 不推荐 - 使用 Alert
<Alert type="success" title="保存成功" />

// ✅ 推荐 - 使用 Toast
async function handleSave() {
  try {
    await saveData()
    toast.success('保存成功')
  } catch (error) {
    toast.error('保存失败')
  }
}
```

**原因：** 保存操作是临时反馈，不需要持久展示。

### 场景 2: 页面级警告

```typescript
// ❌ 不推荐 - 使用 Toast
toast.warning('该功能需要订阅高级版才能使用，详情请查看定价页面')

// ✅ 推荐 - 使用 Alert
<Alert
  type="warning"
  title="功能受限"
  description="该功能需要订阅高级版才能使用"
  closable
>
  <template #default>
    <div class="mt-2">
      <a href="/pricing" class="text-blue-600 hover:underline">
        查看定价详情 →
      </a>
    </div>
  </template>
</Alert>
```

**原因：** 需要用户仔细阅读，包含额外操作，应该持久显示。

### 场景 3: 表单验证

```vue
<script setup>
import { Alert } from '@/components/ui'
import { toast } from '@/utils/toast'

const errors = ref<string[]>([])

async function handleSubmit() {
  // 方式1: 使用 Alert 显示汇总错误
  if (errors.value.length > 0) {
    // Alert 显示在表单上方
  }
  
  // 方式2: 使用 Toast 显示单个错误
  if (!form.username) {
    toast.error('请输入用户名')
    return
  }
}
</script>

<template>
  <div>
    <!-- 汇总错误 - 使用 Alert -->
    <Alert
      v-if="errors.length > 0"
      type="error"
      title="表单验证失败"
      :description="`发现 ${errors.length} 个错误`"
      closable
      class="mb-4"
    >
      <ul class="mt-2 text-sm list-disc list-inside">
        <li v-for="error in errors" :key="error">{{ error }}</li>
      </ul>
    </Alert>

    <!-- 表单 -->
    <form @submit.prevent="handleSubmit">
      <!-- 表单字段 -->
    </form>
  </div>
</template>
```

### 场景 4: 复杂操作流程

```vue
<script setup>
import { Alert } from '@/components/ui'
import { toast } from '@/utils/toast'

// 上传文件
async function uploadFile(file: File) {
  // 1. 开始上传 - Toast 提示
  toast.info('开始上传...')
  
  try {
    await upload(file)
    
    // 2. 上传成功 - Toast 反馈
    toast.success('上传成功')
    
    // 3. 后续处理提示 - Alert 显示
    showProcessingAlert.value = true
    
  } catch (error) {
    toast.error('上传失败')
  }
}
</script>

<template>
  <!-- 处理中的持久提示 -->
  <Alert
    v-if="showProcessingAlert"
    type="info"
    title="文件处理中"
    description="系统正在处理您上传的文件，预计需要 5-10 分钟。处理完成后会通知您。"
    closable
    @close="showProcessingAlert = false"
  />
</template>
```

## 📋 决策树

```
需要提示用户吗？
  │
  ├─ 是 → 这是什么类型的提示？
  │        │
  │        ├─ 操作反馈 (保存/删除/更新等)
  │        │   → 使用 Toast
  │        │
  │        ├─ 临时通知 (复制成功/网络错误等)
  │        │   → 使用 Toast
  │        │
  │        ├─ 页面级重要信息
  │        │   → 使用 Alert
  │        │
  │        ├─ 需要用户仔细阅读
  │        │   → 使用 Alert
  │        │
  │        ├─ 包含额外操作或链接
  │        │   → 使用 Alert
  │        │
  │        └─ 需要持久显示直到用户关闭
  │            → 使用 Alert
  │
  └─ 否 → 不需要提示
```

## 🎨 视觉效果对比

### Toast

```
┌─────────────────────────────────────┐  ← 屏幕右上角
│  ✓  保存成功                         │  ← 自动消失 (2秒)
└─────────────────────────────────────┘
```

### Alert

```
页面内容...

┌─────────────────────────────────────────────────┐
│  ⚠  系统维护通知                      [×]       │  ← 需要手动关闭
│  系统将在今晚 22:00 进行维护，预计持续 2 小时    │
└─────────────────────────────────────────────────┘

页面内容...
```

## 🔧 组合使用示例

### 场景：删除重要数据

```vue
<script setup>
import { Modal, Alert } from '@/components/ui'
import { toast } from '@/utils/toast'

const showDeleteModal = ref(false)

async function handleDelete() {
  try {
    await deleteData()
    
    // 1. 关闭模态框
    showDeleteModal.value = false
    
    // 2. Toast 反馈操作成功
    toast.success('删除成功')
    
    // 3. 如果需要额外说明，使用 Alert
    // showRestoreInfo.value = true
    
  } catch (error) {
    toast.error('删除失败')
  }
}
</script>

<template>
  <!-- Alert: 页面级提示 -->
  <Alert
    v-if="showRestoreInfo"
    type="info"
    title="数据恢复"
    description="已删除的数据将在回收站保留 30 天，期间可以恢复"
    closable
    class="mb-4"
  />

  <!-- Modal: 确认操作 -->
  <Modal
    :open="showDeleteModal"
    title="确认删除"
    @close="showDeleteModal = false"
    @confirm="handleDelete"
  >
    <Alert
      type="warning"
      title="警告"
      description="此操作将永久删除数据，确定要继续吗？"
    />
  </Modal>
</template>
```

## 📝 最佳实践

### Toast 使用规范

✅ **推荐：**
```typescript
// 简短明了
toast.success('保存成功')
toast.error('网络错误')

// 操作反馈
await saveData()
toast.success('保存成功')
```

❌ **避免：**
```typescript
// 太长的文本
toast.info('您的数据已经保存成功，系统将在 5 分钟后自动同步到云端服务器...')

// 需要持久展示的信息
toast.warning('重要：该功能需要订阅高级版...') // 应该用 Alert
```

### Alert 使用规范

✅ **推荐：**
```vue
<!-- 页面顶部的重要提示 -->
<Alert
  type="warning"
  title="账户即将到期"
  description="您的订阅将在 3 天后到期，请及时续费以免影响使用"
  closable
/>

<!-- 表单上方的错误汇总 -->
<Alert
  type="error"
  title="表单验证失败"
  closable
>
  <ul class="text-sm list-disc list-inside">
    <li>用户名不能为空</li>
    <li>密码长度至少 8 位</li>
  </ul>
</Alert>
```

❌ **避免：**
```vue
<!-- 临时的操作反馈 (应该用 Toast) -->
<Alert type="success" title="保存成功" />

<!-- 每次操作都显示 Alert -->
<Alert v-if="justSaved" type="success" title="已保存" />
```

## 🎯 总结

### 选择 Toast 当：
- ✅ 简单的操作反馈
- ✅ 需要自动消失
- ✅ 不打断用户操作
- ✅ 一句话能说清楚
- ✅ 临时性的通知

### 选择 Alert 当：
- ✅ 重要的页面级提示
- ✅ 需要持久展示
- ✅ 包含详细信息
- ✅ 需要用户确认/关闭
- ✅ 包含额外操作或链接
- ✅ 与页面内容相关的上下文提示

### 记住：
> **Toast = 临时 + 简短 + 角落**  
> **Alert = 持久 + 详细 + 内联**

---

**💡 提示：** 两者可以组合使用，Toast 用于即时反馈，Alert 用于持久展示重要信息。
