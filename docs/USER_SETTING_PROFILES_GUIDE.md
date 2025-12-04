# 用户设置配置方案功能使用指南

## 📌 功能概述

用户设置配置方案管理功能允许用户保存、切换和管理不同的设置配置，实现快速切换不同场景的设置（如工作、家庭、出差等）。

## 🎯 核心功能

### 1. 创建配置方案
- 从当前设置创建新配置方案
- 指定方案名称和描述
- 自动保存所有当前设置项

### 2. 切换配置方案
- 一键切换到指定配置方案
- 自动批量更新所有设置
- 切换后自动刷新页面应用设置

### 3. 管理配置方案
- 查看所有配置方案列表
- 显示当前激活的方案
- 默认方案不可删除

### 4. 导入/导出配置
- 导出配置方案为 JSON 文件
- 从 JSON 文件导入配置方案
- 支持配置在不同设备间同步

## 📁 实现结构

### 后端层

#### 服务层
```
src-tauri/crates/money/src/services/user_setting_profiles.rs
```

**核心方法**:
- `create_profile()` - 创建配置方案
- `get_user_profiles()` - 获取用户的所有配置方案
- `get_active_profile()` - 获取当前激活的配置方案
- `switch_profile()` - 切换配置方案
- `create_from_current()` - 从当前设置创建配置方案
- `update_profile()` - 更新配置方案
- `delete_profile()` - 删除配置方案
- `export_profile()` - 导出配置方案
- `import_profile()` - 导入配置方案

#### Tauri 命令层
```
src-tauri/crates/money/src/command.rs
```

**注册的命令**:
- `user_setting_profile_create` - 创建配置方案
- `user_setting_profile_list` - 获取配置方案列表
- `user_setting_profile_get_active` - 获取当前激活的配置方案
- `user_setting_profile_switch` - 切换配置方案
- `user_setting_profile_create_from_current` - 从当前设置创建
- `user_setting_profile_update` - 更新配置方案
- `user_setting_profile_delete` - 删除配置方案
- `user_setting_profile_export` - 导出配置方案
- `user_setting_profile_import` - 导入配置方案

### 前端层

#### 组件
```
src/features/settings/components/SettingProfileManager.vue
```

**功能**:
- 配置方案列表展示
- 创建/删除配置方案
- 切换配置方案
- 导入/导出配置

#### 集成位置
```
src/features/settings/views/GeneralSettings.vue
```

在通用设置页面的底部，配置方案管理组件被集成在一个独立的区域中。

## 🚀 使用方法

### 1. 访问配置方案管理

1. 打开应用
2. 进入**设置** -> **通用**
3. 滚动到页面底部，找到"配置方案管理"部分

### 2. 创建配置方案

```
步骤：
1. 先调整好你想保存的所有设置（主题、语言、时区等）
2. 点击"新建方案"按钮
3. 输入方案名称（如："工作配置"）
4. 可选：输入描述说明
5. 点击"保存"
```

**示例场景**:
- **工作配置**: 浅色主题、中文、紧凑模式开启
- **家庭配置**: 深色主题、英文、紧凑模式关闭
- **出差配置**: 自动主题、其他时区

### 3. 切换配置方案

```
步骤：
1. 在配置方案列表中找到目标方案
2. 点击方案卡片上的"切换"按钮（齿轮图标）
3. 等待应用所有设置
4. 页面自动刷新，新配置生效
```

### 4. 导出配置方案

```
步骤：
1. 在配置方案列表中找到目标方案
2. 点击"导出"按钮（下载图标）
3. 保存 JSON 文件到本地
```

**用途**:
- 备份配置
- 在不同设备间同步配置
- 分享给团队成员

### 5. 导入配置方案

```
步骤：
1. 点击"导入"按钮
2. 选择之前导出的 JSON 文件
3. 配置方案自动添加到列表
```

### 6. 删除配置方案

```
步骤：
1. 在配置方案列表中找到目标方案
2. 点击"删除"按钮（垃圾桶图标）
3. 确认删除操作
```

**限制**:
- ❌ 不能删除默认配置方案
- ❌ 不能删除当前激活的配置方案（请先切换到其他方案）

## 💾 数据存储

### 数据库表结构

```sql
CREATE TABLE user_setting_profiles (
  serial_num VARCHAR(38) PRIMARY KEY,
  user_serial_num VARCHAR(38) NOT NULL,
  profile_name VARCHAR NOT NULL,
  profile_data JSON NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  description VARCHAR,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### 配置数据格式

```json
{
  "settings.general.theme": "dark",
  "settings.general.locale": "zh-CN",
  "settings.general.timezone": "Asia/Shanghai",
  "settings.general.compactMode": true,
  "settings.general.autoStart": false
}
```

## 🧪 测试步骤

### 基础功能测试

1. **创建配置方案**
   ```
   ✓ 修改一些设置（主题、语言等）
   ✓ 创建新配置方案
   ✓ 验证配置方案出现在列表中
   ✓ 验证当前激活标记正确
   ```

2. **切换配置方案**
   ```
   ✓ 创建两个不同的配置方案
   ✓ 切换到第二个配置方案
   ✓ 验证所有设置已更新
   ✓ 验证激活标记已切换
   ```

3. **删除配置方案**
   ```
   ✓ 创建测试配置方案
   ✓ 切换到其他方案
   ✓ 删除测试配置方案
   ✓ 验证方案已从列表中移除
   ```

4. **导出/导入配置**
   ```
   ✓ 导出一个配置方案
   ✓ 验证 JSON 文件内容正确
   ✓ 删除原配置方案
   ✓ 导入刚才的 JSON 文件
   ✓ 验证配置方案已恢复
   ```

### 边界情况测试

1. **权限测试**
   ```
   ✓ 尝试删除默认配置方案（应该失败）
   ✓ 尝试删除当前激活的配置方案（应该失败）
   ```

2. **并发测试**
   ```
   ✓ 快速切换多个配置方案
   ✓ 在配置方案切换时尝试修改设置
   ```

3. **数据完整性**
   ```
   ✓ 导出后修改配置
   ✓ 切换回之前导出的配置方案
   ✓ 验证设置已正确恢复
   ```

## 🐛 故障排查

### 问题 1: 切换配置后设置未生效

**可能原因**:
- 页面未刷新
- 配置数据格式错误

**解决方法**:
```javascript
// 检查浏览器控制台是否有错误
// 手动刷新页面: F5 或 Ctrl+R
```

### 问题 2: 无法删除配置方案

**可能原因**:
- 配置方案是默认方案
- 配置方案正在被使用

**解决方法**:
```
1. 检查是否有"默认"或"当前"标签
2. 如果是当前方案，先切换到其他方案
3. 如果是默认方案，无法删除
```

### 问题 3: 导入失败

**可能原因**:
- JSON 文件格式错误
- 文件版本不兼容

**解决方法**:
```javascript
// 验证 JSON 文件格式
{
  "version": "1.0",
  "profile_name": "配置名称",
  "description": "描述",
  "profile_data": { /* 设置数据 */ }
}
```

## 📊 技术细节

### 工作流程

```
创建配置方案:
  用户点击"新建方案"
    ↓
  输入名称和描述
    ↓
  前端调用 create_from_current 命令
    ↓
  后端获取所有当前设置
    ↓
  保存到 user_setting_profiles 表
    ↓
  返回新创建的配置方案
```

```
切换配置方案:
  用户点击"切换"
    ↓
  前端调用 switch_profile 命令
    ↓
  后端停用所有配置方案
    ↓
  激活目标配置方案
    ↓
  批量更新 user_settings 表
    ↓
  返回成功，前端刷新页面
```

### API 响应格式

```typescript
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
}

interface SettingProfile {
  serialNum: string;
  userSerialNum: string;
  profileName: string;
  profileData: Record<string, any>;
  isActive: boolean;
  isDefault: boolean;
  description?: string;
  createdAt: string;
  updatedAt: string;
}
```

## 🔮 未来扩展

### 计划功能

1. **自动切换**
   - 根据时间自动切换配置
   - 根据位置自动切换配置

2. **配置模板**
   - 预设配置模板（工作、学习、娱乐等）
   - 一键应用模板

3. **协作功能**
   - 团队共享配置方案
   - 配置方案审批流程

4. **版本控制**
   - 配置方案版本历史
   - 回退到历史版本

## 📝 注意事项

1. **数据同步**
   - 配置方案不会自动同步到云端
   - 需要手动导出/导入实现跨设备同步

2. **性能考虑**
   - 配置方案包含所有设置数据
   - 建议保持配置方案数量在合理范围（< 10个）

3. **安全性**
   - 配置数据存储在本地数据库
   - 导出的 JSON 文件可能包含敏感信息，请妥善保管

4. **兼容性**
   - 配置方案格式可能在未来版本中变化
   - 导入旧版本配置时可能需要手动调整

## 📞 技术支持

如遇问题，请提供以下信息：
- 操作步骤
- 错误信息
- 浏览器控制台日志
- 配置方案 JSON 文件（如涉及导入/导出问题）

---

**版本**: 1.0.0  
**最后更新**: 2024-12-04  
**作者**: Miji Development Team
