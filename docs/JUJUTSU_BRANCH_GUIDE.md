# 🌿 Jujutsu 分支（Bookmark）操作指南

## 📖 核心概念

### Git vs Jujutsu 术语

| Git | Jujutsu | 说明 |
|-----|---------|------|
| branch | bookmark | 指向某个变更的命名指针 |
| HEAD | @ | 当前工作的变更 |
| commit | change | 一次代码变更 |

### 重要理解

在 Jujutsu 中：
- **变更（change）** 是核心，有唯一的 change-id
- **书签（bookmark）** 是指向变更的可选标签
- 可以在没有书签的情况下工作（基于 change-id）

## 🎯 基本分支操作

### 1. 查看分支（书签）

```bash
# 查看所有书签
jj bookmark list

# 查看包含远程书签
jj bookmark list --all

# 查看当前书签
jj log -r @
```

### 2. 创建分支

```bash
# 方式 1: 创建新书签指向当前变更
jj bookmark create feature-x

# 方式 2: 创建新变更并同时创建书签
jj new -m "feat: start feature X"
jj bookmark create feature-x

# 方式 3: 基于特定变更创建书签
jj bookmark create feature-x -r <change-id>
```

### 3. 切换分支

```bash
# 方式 1: 通过书签名切换
jj new feature-x

# 方式 2: 通过 change-id 切换
jj edit <change-id>

# 方式 3: 切换到远程分支
jj new main@origin
```

### 4. 移动分支

```bash
# 将书签移动到当前变更
jj bookmark set feature-x

# 将书签移动到指定变更
jj bookmark set feature-x -r <change-id>
```

### 5. 删除分支

```bash
# 删除本地书签
jj bookmark delete feature-x

# 删除远程书签
jj bookmark delete feature-x@origin
```

### 6. 重命名分支

```bash
# 重命名书签
jj bookmark rename old-name new-name
```

## 🔄 与远程分支协作

### 跟踪远程分支

```bash
# 跟踪单个远程书签
jj bookmark track main@origin

# 跟踪多个远程书签
jj bookmark track main@origin dev@origin

# 查看跟踪状态
jj bookmark list --all
```

### 推送分支

```bash
# 推送当前分支
jj git push

# 推送指定分支
jj git push --bookmark feature-x

# 推送所有分支
jj git push --all

# 强制推送（谨慎使用）
jj git push --bookmark feature-x --force
```

### 拉取远程更新

```bash
# 获取所有远程更新
jj git fetch

# 获取指定远程
jj git fetch --remote origin

# 查看远程更新
jj log -r 'remote_bookmarks()'
```

### 同步远程分支

```bash
# 拉取并变基到最新的 main
jj git fetch
jj rebase -d main@origin

# 或者使用 bookmark track 自动跟踪
jj bookmark track main@origin
jj git fetch  # 自动更新本地 main 书签
```

## 💡 实际工作流示例

### 场景 1: 创建功能分支

```bash
# 1. 确保在最新的 main 上
jj git fetch
jj new main@origin

# 2. 创建功能分支书签
jj bookmark create feature/user-login
jj describe -m "feat: implement user login"

# 3. 开发...
# 编辑文件

# 4. 查看更改
jj status
jj diff

# 5. 提交更多变更（如果需要）
jj commit -m "feat: add login form"
jj commit -m "feat: add validation"

# 6. 推送到远程
jj git push --bookmark feature/user-login
```

### 场景 2: 切换到其他分支工作

```bash
# 1. 保存当前工作（自动保存，无需操作）

# 2. 切换到另一个分支
jj new main@origin
jj bookmark create feature/fix-bug

# 3. 工作...
jj describe -m "fix: resolve login issue"

# 4. 切换回之前的分支
jj new feature/user-login

# 5. 继续之前的工作
```

### 场景 3: 同步远程更新

```bash
# 1. 获取远程更新
jj git fetch

# 2. 查看有什么更新
jj log -r 'main@origin'

# 3. 将你的工作变基到最新 main
jj rebase -d main@origin

# 4. 如果有冲突，解决后继续
jj resolve --list
# 编辑冲突文件...
jj resolve --mark <file>
```

### 场景 4: 合并功能到主分支

```bash
# 方式 1: 使用 Git 合并（推荐，团队协作）
jj git push --bookmark feature/user-login
# 然后在 GitHub 上创建 PR 并合并

# 方式 2: 本地合并（个人项目）
jj new main
jj bookmark set main
jj squash -r feature/user-login
jj git push
```

## 🔧 高级技巧

### 1. 并行开发多个功能

```bash
# 创建多个分支
jj new main@origin
jj bookmark create feature-A
jj describe -m "feature A"

jj new main@origin
jj bookmark create feature-B
jj describe -m "feature B"

# 在它们之间切换
jj new feature-A  # 工作在 A
jj new feature-B  # 工作在 B

# 查看所有分支
jj log --all
```

### 2. 基于某个变更创建分支

```bash
# 查看历史找到目标变更
jj log

# 基于该变更创建新分支
jj new <change-id>
jj bookmark create fix-from-old-commit
```

### 3. 将变更应用到多个分支

```bash
# 在 feature-A 上做了一个变更
jj new feature-A
jj describe -m "shared: common util"

# 将这个变更也应用到 feature-B
jj duplicate <change-id>
jj rebase -d feature-B
jj bookmark set feature-B
```

### 4. 查看分支差异

```bash
# 查看两个书签之间的差异
jj log -r 'feature-A..feature-B'

# 查看与主分支的差异
jj diff -r 'main..@'

# 查看分支的提交列表
jj log -r 'ancestors(@) ~ ancestors(main)'
```

## 📊 分支状态可视化

### 查看分支图

```bash
# 图形化显示所有分支
jj log --all

# 只显示最近的分支
jj log -r 'all:heads()' -n 20

# 显示特定范围
jj log -r 'ancestors(@, 10)'
```

### 理解输出

```
◉  qworqutr <you> [now] feature-x 3b727a87
│  feat: add new feature
◉  mlonqyku <you> [1 day ago] main 892197a9
│  fix: previous commit
│
```

- `◉` = 变更节点
- `│` = 分支线
- `feature-x` = 书签名
- `3b727a87` = change-id 前缀

## ⚠️ 注意事项

### 1. 推送前检查

```bash
# 推送前先查看要推送什么
jj log -r 'mine() & ::@'

# 确认后再推送
jj git push
```

### 2. 远程分支命名

```bash
# 本地书签
feature-x           # 本地
feature-x@origin    # 远程

# 跟踪远程分支后，拉取会自动更新本地
jj bookmark track feature-x@origin
jj git fetch  # 自动更新本地 feature-x
```

### 3. 删除远程分支

```bash
# 删除本地书签
jj bookmark delete feature-x

# 删除远程书签（需要推送）
jj bookmark delete feature-x@origin
jj git push --bookmark feature-x --delete

# 或使用 git 命令
git push origin --delete feature-x
```

## 🆚 与 Git 分支对比

### Git 工作流
```bash
# Git
git checkout -b feature-x
git add .
git commit -m "feat: add feature"
git push origin feature-x
git checkout main
git pull origin main
git merge feature-x
git push origin main
```

### Jujutsu 等价工作流
```bash
# Jujutsu
jj new main@origin
jj bookmark create feature-x
jj describe -m "feat: add feature"
jj git push --bookmark feature-x
jj new main@origin
jj git fetch
jj squash -r feature-x  # 或在 GitHub 上合并 PR
jj git push
```

## 🎓 最佳实践

### 1. 分支命名

```bash
# 推荐的命名规范
jj bookmark create feature/user-auth
jj bookmark create fix/login-bug
jj bookmark create refactor/api-client
jj bookmark create docs/readme-update
```

### 2. 保持分支同步

```bash
# 每天开始工作前
jj git fetch
jj rebase -d main@origin

# 定期推送
jj git push --bookmark feature-x
```

### 3. 使用描述性提交信息

```bash
# 好的提交信息
jj describe -m "feat: add user authentication with JWT"

# 不好的提交信息
jj describe -m "update"
```

### 4. 小步提交

```bash
# 将大功能拆分为多个小变更
jj commit -m "feat: add login form UI"
jj commit -m "feat: add login API integration"
jj commit -m "feat: add login error handling"
jj commit -m "test: add login tests"
```

## 🔍 故障排查

### 分支未显示

```bash
# 检查是否跟踪远程分支
jj bookmark list --all

# 跟踪缺失的分支
jj bookmark track <branch>@origin
```

### 推送失败

```bash
# 检查远程配置
git remote -v

# 检查要推送的内容
jj log -r ::@

# 强制推送（谨慎）
jj git push --force
```

### 分支冲突

```bash
# 查看冲突
jj status

# 解决冲突
# 编辑文件...
jj resolve --mark <file>

# 继续变基
jj rebase --continue
```

## 📚 快速参考

### 常用命令

| 操作 | 命令 |
|------|------|
| 列出分支 | `jj bookmark list` |
| 创建分支 | `jj bookmark create <name>` |
| 切换分支 | `jj new <bookmark>` |
| 删除分支 | `jj bookmark delete <name>` |
| 推送分支 | `jj git push --bookmark <name>` |
| 拉取更新 | `jj git fetch` |
| 跟踪远程 | `jj bookmark track <name>@origin` |
| 变基 | `jj rebase -d <target>` |

### 分支操作速查

```bash
# 完整的功能分支流程
jj git fetch                              # 1. 拉取最新
jj new main@origin                        # 2. 基于最新 main
jj bookmark create feature/new-feature    # 3. 创建分支
jj describe -m "feat: implement feature"  # 4. 描述功能
# ... 编辑代码 ...                         # 5. 开发
jj git push --bookmark feature/new-feature # 6. 推送
```

---

## 🖥️ 新电脑设置

**换新电脑或新克隆仓库？**

`.jj/` 目录不推送到远程，但这完全没问题！只需重新初始化：

```bash
# 1. 克隆仓库
git clone <repo>
cd <repo>

# 2. 初始化 Jujutsu
jj git init --colocate

# 3. 跟踪分支
jj bookmark track main@origin

# 4. 配置用户
jj config set --user user.name "Your Name"
jj config set --user user.email "your@email.com"

# ✅ 完成！所有历史都会自动从 .git/ 导入
jj log  # 查看完整历史
```

📖 **详细说明**: [新电脑设置指南](./JUJUTSU_NEW_MACHINE_SETUP.md)

**为什么不会丢失历史？**
- 真正的历史在 `.git/` 目录中（会推送）✅
- `.jj/` 只是本地操作状态（不推送）
- Jujutsu 会自动导入所有 Git 历史

---

**需要更多帮助？查看相关文档:**
- 📖 [新电脑设置指南](./JUJUTSU_NEW_MACHINE_SETUP.md) - 换电脑必读
- 📖 [完整使用指南](./JUJUTSU_GUIDE.md) - 深入学习
