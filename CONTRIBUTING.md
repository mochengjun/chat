# 贡献指南

感谢您有兴趣为 Secure Enterprise Chat 做贡献！

## 目录

- [行为准则](#行为准则)
- [如何贡献](#如何贡献)
- [开发流程](#开发流程)
- [代码规范](#代码规范)
- [提交信息规范](#提交信息规范)
- [Pull Request 流程](#pull-request-流程)
- [问题报告](#问题报告)

---

## 行为准则

本项目采用贡献者公约作为行为准则。参与本项目即表示您同意遵守其条款。请阅读 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) 了解详情。

---

## 如何贡献

### 报告 Bug

如果您发现了 Bug，请通过 [GitHub Issues](https://github.com/mochengjun/sec-chat/issues) 提交报告。

在提交 Bug 报告前，请：

1. 搜索现有 Issues，确认该问题尚未被报告
2. 使用最新的主分支代码测试，确认问题仍然存在
3. 收集相关日志和截图

### 提出新功能

如果您有新功能的想法，欢迎通过 Issues 提交功能请求。

请详细描述：

1. 该功能解决的问题
2. 期望的解决方案
3. 可能的替代方案
4. 相关的参考实现

### 提交代码

我们欢迎所有形式的代码贡献！请遵循以下流程：

---

## 开发流程

### 1. Fork 并克隆仓库

```bash
# Fork 后克隆您的仓库
git clone https://github.com/YOUR_USERNAME/sec-chat.git
cd sec-chat

# 添加上游仓库
git remote add upstream https://github.com/mochengjun/sec-chat.git
```

### 2. 创建功能分支

```bash
# 同步主仓库
git fetch upstream
git checkout main
git merge upstream/main

# 创建功能分支
git checkout -b feature/your-feature-name
```

分支命名规范：

- `feature/xxx` - 新功能
- `fix/xxx` - Bug 修复
- `docs/xxx` - 文档更新
- `refactor/xxx` - 代码重构
- `test/xxx` - 测试相关

### 3. 开发环境搭建

#### Flutter 应用

```bash
cd apps/flutter_app
flutter pub get
flutter run
```

#### Web 客户端

```bash
cd web-client
pnpm install
pnpm dev
```

#### Go 服务

```bash
cd services/auth-service
go mod download
go run cmd/main.go
```

### 4. 编写代码

- 遵循项目的代码规范
- 编写单元测试
- 更新相关文档

### 5. 提交代码

请遵循 [约定式提交](https://www.conventionalcommits.org/) 规范：

```bash
git add .
git commit -m "feat(scope): your changes description"
```

### 6. 推送并创建 PR

```bash
git push origin feature/your-feature-name
```

然后在 GitHub 上创建 Pull Request。

---

## 代码规范

### Flutter/Dart

- 使用 `dart format` 格式化代码
- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 指南
- 使用 `flutter analyze` 进行静态分析

### TypeScript/React

- 使用 ESLint 和 Prettier 格式化代码
- 遵循 [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- 组件使用函数式组件和 Hooks

### Go

- 使用 `gofmt` 格式化代码
- 遵循 [Effective Go](https://golang.org/doc/effective_go) 指南
- 使用 `golangci-lint` 进行静态分析

---

## 提交信息规范

### 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 类型 (type)

| 类型 | 说明 |
|------|------|
| feat | 新功能 |
| fix | Bug 修复 |
| docs | 文档更新 |
| style | 代码格式 |
| refactor | 代码重构 |
| test | 测试相关 |
| chore | 构建/工具 |
| perf | 性能优化 |
| ci | CI 配置 |

### 作用域 (scope)

- `flutter-app` - Flutter 应用
- `web-client` - Web 客户端
- `auth-service` - 认证服务
- `push-service` - 推送服务
- `docker` - Docker 配置
- `k8s` - Kubernetes 配置
- `ci` - CI/CD 配置

### 示例

```bash
# 新功能
feat(auth-service): add OAuth2.0 authentication

# Bug 修复
fix(web-client): resolve WebSocket reconnection issue

# 破坏性变更
feat(api)!: change user authentication endpoint response format

BREAKING CHANGE: The /api/auth/login endpoint now returns
user profile in a nested object instead of flat structure.
```

---

## Pull Request 流程

### PR 检查清单

- [ ] 代码遵循项目编码规范
- [ ] 已进行自我代码审查
- [ ] 代码有充分的注释
- [ ] 相关文档已更新
- [ ] 没有引入新的警告
- [ ] 新代码有对应的单元测试
- [ ] 所有测试通过

### 审查流程

1. 提交 PR 后，CI 自动运行测试
2. 至少需要 1 位审查人员批准
3. 所有 CI 检查必须通过
4. 解决所有审查意见
5. 合并到目标分支

### 合并策略

| 分支类型 | 合并方式 |
|---------|---------|
| feature/* → develop | Squash merge |
| develop → main | Merge commit |
| hotfix/* → main | Merge commit |

---

## 版本发布流程

### 版本号规范

本项目采用 [语义化版本控制](https://semver.org/lang/zh-CN/) (SemVer) 标准：

```
v[主版本].[次版本].[修订号][-预发布标识]
```

**版本递增规则：**

- **主版本 (MAJOR)**: 不兼容的 API 变更时递增
- **次版本 (MINOR)**: 向后兼容的功能新增时递增
- **修订号 (PATCH)**: 向后兼容的问题修复时递增

**预发布标识：**

- `-alpha.x`: 内部测试版本（如 `v1.0.0-alpha.1`）
- `-beta.x`: 公开测试版本（如 `v1.0.0-beta.1`）
- `-rc.x`: 候选发布版本（如 `v1.0.0-rc.1`）

### 分支命名规范（扩展）

除基本分支类型外，版本发布相关分支：

- `release/v[版本号]` - 版本发布准备分支（如 `release/v1.2.0`）
- `hotfix/v[版本号]` - 紧急修复分支（如 `hotfix/v1.2.1`）

### 版本发布步骤

#### 1. 准备发布分支

```bash
# 从 develop 分支创建发布分支
git checkout develop
git pull upstream develop
git checkout -b release/v1.2.0
```

#### 2. 更新版本信息

- 更新 `CHANGELOG.md`，将 `[Unreleased]` 内容移至新版本
- 更新各模块版本号（如 `pubspec.yaml`, `package.json`, `go.mod` 等）
- 提交更改：

```bash
git add -A
git commit -m "chore(release): prepare for v1.2.0"
```

#### 3. 创建 Pull Request

- 创建 PR 从 `release/v1.2.0` 合并到 `main`
- 创建 PR 从 `release/v1.2.0` 合并回 `develop`
- 确保所有 CI 检查通过
- 获得至少 1 位维护者审查批准

#### 4. 合并并打标签

```bash
# 合并到 main 分支后
git checkout main
git pull upstream main

# 创建附注标签（推荐）
git tag -a v1.2.0 -m "Release version 1.2.0"

# 或者创建轻量标签
git tag v1.2.0

# 推送标签到远程
git push upstream v1.2.0
```

#### 5. 发布版本

- 在 GitHub 上创建 Release，基于新标签
- 填写发布说明，包含主要变更摘要
- 如有必要，上传构建产物

### 紧急修复 (Hotfix) 流程

当生产环境发现严重 Bug 需要立即修复时：

```bash
# 从 main 分支创建 hotfix 分支
git checkout main
git pull upstream main
git checkout -b hotfix/v1.2.1

# 修复 Bug 并提交
git commit -m "fix(auth-service): resolve critical login issue"

# 更新版本号和 CHANGELOG
git commit -m "chore(release): bump version to v1.2.1"
```

**注意：** Hotfix 需要同时合并到 `main` 和 `develop` 分支。

### 版本发布检查清单

- [ ] 所有相关 PR 已合并到 develop
- [ ] CHANGELOG.md 已更新
- [ ] 版本号已在各配置文件中更新
- [ ] 所有测试通过
- [ ] 文档已更新
- [ ] 发布分支已通过代码审查
- [ ] 标签已正确创建并推送
- [ ] GitHub Release 已创建

### 版本管理注意事项

1. **不要修改已发布标签**：一旦标签推送到远程，不应修改或删除
2. **保持版本号一致性**：确保 Git 标签、CHANGELOG、配置文件中的版本号一致
3. **及时更新 CHANGELOG**：每次发布前确保变更日志完整准确
4. **预发布版本标记**：非稳定版本必须带 `-alpha`, `-beta`, `-rc` 标识
5. **向后兼容优先**：尽量避免破坏性变更，必要时递增主版本号

---

## 问题报告

如果您在使用过程中遇到问题，可以通过以下方式获取帮助：

- [GitHub Issues](https://github.com/mochengjun/sec-chat/issues) - Bug 报告和功能请求
- [GitHub Discussions](https://github.com/mochengjun/sec-chat/discussions) - 一般讨论和问答
- 邮件: security@example.com - 安全问题（敏感信息请勿公开）

---

## 许可证

通过贡献代码，您同意您的代码将在项目的 MIT 许可证下授权。

---

再次感谢您的贡献！🙏
