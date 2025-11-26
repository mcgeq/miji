# 📦 包管理器使用说明 - Bun

## 🎯 项目使用 Bun

本项目使用 **Bun** 作为包管理器和运行时，而不是 npm。

## 📋 常用命令对照表

| 任务 | npm 命令 | Bun 命令 |
|------|---------|----------|
| **安装依赖** | `npm install` | `bun install` |
| **添加包** | `npm install <pkg>` | `bun add <pkg>` |
| **添加开发依赖** | `npm install -D <pkg>` | `bun add -d <pkg>` |
| **移除包** | `npm uninstall <pkg>` | `bun remove <pkg>` |
| **查看已安装包** | `npm list` | `bun pm ls` |
| **查看特定包** | `npm list <pkg>` | `bun pm ls <pkg>` |
| **运行脚本** | `npm run <script>` | `bun run <script>` 或 `bun <script>` |
| **更新依赖** | `npm update` | `bun update` |
| **清理缓存** | `npm cache clean` | `bun pm cache rm` |

## 🚀 本项目常用命令

### 开发
```bash
# 启动开发服务器
bun run dev

# 或直接使用
bun dev
```

### 构建
```bash
# 构建生产版本
bun run build

# 预览构建结果
bun run preview
```

### Tauri
```bash
# 启动 Tauri 开发环境
bun run tauri:dev

# 构建 Tauri 应用
bun run tauri:build

# Windows 构建
bun run build:win

# Android 构建
bun run build:android
```

### 测试
```bash
# 运行测试
bun test

# 或
bun run test
```

### 代码质量
```bash
# 格式化代码
bun run format

# 代码检查
bun run lint

# 修复问题
bun run lint:fix
```

### Git 提交
```bash
# 使用 commitizen
bun run commit
```

## 🎨 Headless UI 重构相关命令

### 安装依赖
```bash
# 安装 Headless UI Vue
bun add @headlessui/vue

# 移除不需要的 PostCSS 插件
bun remove postcss-import postcss-nested postcss-preset-env
```

### 验证安装
```bash
# 检查 Tailwind CSS 版本
bun pm ls tailwindcss

# 检查所有依赖
bun pm ls
```

## 🔧 Bun 的优势

### 1. 速度快
- **安装速度提升 20-100x** - 比 npm/yarn/pnpm 更快
- **启动速度提升 4x** - 更快的开发服务器
- **测试运行提升 3x** - 内置测试运行器

### 2. 功能完整
- **包管理器** - 兼容 npm/yarn 生态
- **运行时** - 原生支持 TypeScript/JSX
- **打包工具** - 内置打包器
- **测试运行器** - 内置测试框架

### 3. 兼容性好
- **npm 兼容** - 使用 `package.json`
- **lockfile 兼容** - 自动转换 `package-lock.json`
- **脚本兼容** - 支持所有 npm scripts

## 📝 项目配置

### package.json
```json
{
  "name": "miji",
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc --noEmit && vite build",
    "preview": "vite preview",
    "tauri:dev": "tauri dev",
    "tauri:build": "tauri build",
    "test": "vitest",
    "commit": "git add . && cz",
    "format": "biome format --write src && eslint --fix src",
    "lint": "biome check src && eslint src",
    "lint:fix": "biome check --write --unsafe src && eslint --fix src"
  }
}
```

### bun.lockb
- Bun 使用二进制锁文件 `bun.lockb`
- 比 `package-lock.json` 更快
- 自动生成和更新

## 🚨 注意事项

### 1. 全局安装
```bash
# 如果还没有安装 Bun
curl -fsSL https://bun.sh/install | bash

# Windows (使用 PowerShell)
powershell -c "irm bun.sh/install.ps1|iex"
```

### 2. 升级 Bun
```bash
# 升级到最新版本
bun upgrade
```

### 3. 环境变量
```bash
# 查看 Bun 版本
bun --version

# 查看 Bun 安装路径
which bun
```

### 4. IDE 集成
- **VS Code**: 安装 "Bun for Visual Studio Code" 插件
- **WebStorm**: 内置支持 Bun

## 📊 性能对比

| 操作 | npm | yarn | pnpm | Bun | 速度提升 |
|------|-----|------|------|-----|---------|
| **初次安装** | 51.0s | 39.1s | 24.7s | 0.9s | 56x 🚀 |
| **有缓存安装** | 30.4s | 18.9s | 12.3s | 0.5s | 60x 🚀 |
| **lockfile 更新** | 19.7s | 11.2s | 7.8s | 0.3s | 65x 🚀 |

## 🔗 相关资源

- [Bun 官方文档](https://bun.sh/docs)
- [Bun GitHub](https://github.com/oven-sh/bun)
- [Bun vs npm/yarn/pnpm](https://bun.sh/docs/cli/install#performance)
- [Bun Discord 社区](https://bun.sh/discord)

## ✅ 快速检查

### 验证 Bun 是否正常工作
```bash
# 1. 检查 Bun 版本
bun --version

# 2. 安装项目依赖
bun install

# 3. 运行开发服务器
bun dev

# 4. 所有测试
bun test
```

如果以上命令都正常工作，说明 Bun 环境配置正确！

---

**💡 提示：** 在所有文档中，请使用 `bun` 命令而不是 `npm`！
