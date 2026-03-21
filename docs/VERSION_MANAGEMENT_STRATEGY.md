# GitHub 版本管理策略

> **文档版本**: v1.0.0  
> **最后更新**: 2025-03-17  
> **适用范围**: Secure Enterprise Chat 全项目

---

## 目录

1. [Git 工作流规范](#1-git-工作流规范)
2. [提交信息规范化标准](#2-提交信息规范化标准)
3. [分支管理与保护策略](#3-分支管理与保护策略)
4. [标签管理与版本控制](#4-标签管理与版本控制)
5. [双仓库同步方案](#5-双仓库同步方案)
6. [GitHub Actions 自动化流水线](#6-github-actions-自动化流水线)
7. [仓库配置与模板](#7-仓库配置与模板)
8. [团队协作流程](#8-团队协作流程)

---

## 1. Git 工作流规范

### 1.1 分支模型概述

本项目采用 **GitFlow** 工作流的简化版本，结合 **GitHub Flow** 的轻量级特点：

```
                    ┌─────────────────────────────────────────┐
                    │              main (生产环境)              │
                    │  受保护分支 | 仅通过 PR 合并 | 自动部署    │
                    └─────────────────────────────────────────┘
                                      ▲
                                      │ merge (squash)
                    ┌─────────────────────────────────────────┐
                    │            develop (开发集成)            │
                    │  受保护分支 | 日常开发集成 | 预发布验证   │
                    └─────────────────────────────────────────┘
                                      ▲
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
          ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
          │ feature/xxx    │  │ fix/xxx        │  │ release/vX.Y.Z │
          │ 功能开发分支    │  │ 问题修复分支    │  │ 发布准备分支    │
          └────────────────┘  └────────────────┘  └────────────────┘
```

### 1.2 主要分支定义

| 分支类型 | 分支名称 | 用途 | 生命周期 | 保护级别 |
|---------|---------|------|---------|---------|
| **主分支** | `main` | 生产环境稳定代码 | 永久 | 高 |
| **开发分支** | `develop` | 功能集成与预发布验证 | 永久 | 中 |
| **功能分支** | `feature/*` | 新功能开发 | 临时 | 低 |
| **修复分支** | `fix/*` | Bug 修复 | 临时 | 低 |
| **发布分支** | `release/*` | 版本发布准备 | 临时 | 中 |
| **热修分支** | `hotfix/*` | 生产环境紧急修复 | 临时 | 中 |

### 1.3 分支命名规范

#### 功能分支 (Feature)
```
feature/[模块名]-[简要描述]

示例:
feature/user-authentication-flow      # 用户认证流程
feature/webrtc-video-call           # WebRTC 视频通话
feature/push-notification-system    # 推送通知系统
feature/chat-room-encryption        # 聊天室加密
```

#### 修复分支 (Fix)
```
fix/[问题类型]-[简要描述]

示例:
fix/security-vulnerability-in-login  # 登录安全漏洞
fix/memory-leak-in-webrtc           # WebRTC 内存泄漏
fix/database-connection-timeout     # 数据库连接超时
fix/ui-crash-on-message-send        # 发送消息时 UI 崩溃
```

#### 发布分支 (Release)
```
release/v[主版本].[次版本].[修订号]

示例:
release/v1.0.0     # 首个正式版本
release/v1.1.0     # 功能新增版本
release/v1.0.1     # Bug 修复版本
release/v2.0.0     # 重大架构变更
```

#### 热修分支 (Hotfix)
```
hotfix/v[主版本].[次版本].[修订号]-[简短描述]

示例:
hotfix/v1.0.1-critical-security-patch  # 紧急安全补丁
hotfix/v1.0.2-database-failover        # 数据库故障转移
```

### 1.4 组件特定分支策略

#### Flutter 应用 (`apps/flutter_app`)
```
apps/flutter_app/
├── feature/flutter-[功能名]     # Flutter 功能开发
├── fix/flutter-[问题描述]       # Flutter 问题修复
└── release/flutter-vX.Y.Z       # Flutter 版本发布

特殊考虑:
- iOS/Android 平台特定修改需在分支名中标注平台
- 示例: feature/flutter-ios-sign-in-with-apple
- 示例: fix/flutter-android-background-service
```

#### Web 客户端 (`web-client`)
```
web-client/
├── feature/web-[功能名]         # Web 功能开发
├── fix/web-[问题描述]           # Web 问题修复
└── release/web-vX.Y.Z           # Web 版本发布

特殊考虑:
- 响应式设计优化需标注 responsive
- 示例: feature/web-responsive-dashboard
- 示例: fix/web-safari-webrtc-compatibility
```

#### Go 服务 (`services/*`)
```
services/
├── auth-service/
│   ├── feature/auth-[功能名]    # 认证服务功能
│   └── fix/auth-[问题描述]      # 认证服务修复
├── push-service/
│   ├── feature/push-[功能名]    # 推送服务功能
│   └── fix/push-[问题描述]      # 推送服务修复
└── ...

特殊考虑:
- 多服务共同修改使用 shared 前缀
- 示例: feature/shared-api-versioning
- 示例: fix/shared-database-connection-pool
```

---

## 2. 提交信息规范化标准

### 2.1 约定式提交规范 (Conventional Commits 1.0.0)

本项目严格遵循 [约定式提交](https://www.conventionalcommits.org/) 规范。

#### 提交信息格式
```
<type>(<scope>): <short summary>

[optional body]

[optional footer(s)]
```

### 2.2 提交类型定义

| 类型 | 说明 | 使用场景 | 示例 |
|-----|------|---------|------|
| `feat` | 新功能 | 新增功能特性 | `feat(auth): add OAuth2.0 authentication` |
| `fix` | Bug 修复 | 修复缺陷或漏洞 | `fix(web): resolve WebSocket reconnection issue` |
| `docs` | 文档更新 | 文档变更 | `docs: update API documentation for v1.2` |
| `style` | 代码格式 | 不影响逻辑的格式调整 | `style(flutter): format code with dart format` |
| `refactor` | 代码重构 | 不修复 bug 也不添加功能的改进 | `refactor(auth): simplify token validation logic` |
| `test` | 测试相关 | 添加或修改测试 | `test(auth): add unit tests for JWT validation` |
| `chore` | 构建/工具 | 构建过程或辅助工具变动 | `chore(ci): update GitHub Actions workflow` |
| `perf` | 性能优化 | 性能改进 | `perf(db): optimize query performance` |
| `ci` | CI 配置 | CI/CD 配置变更 | `ci: add automated deployment pipeline` |
| `build` | 构建系统 | 构建系统或外部依赖变更 | `build(deps): upgrade Go to 1.23` |
| `revert` | 回滚提交 | 回滚之前的提交 | `revert: revert "feat(auth): add OAuth2.0"` |

### 2.3 Scope (作用域) 定义

#### 按模块划分
```
flutter-app    # Flutter 移动应用
web-client     # Web 前端客户端
auth-service   # 认证服务
push-service   # 推送服务
media-proxy    # 媒体代理
admin-service  # 管理服务
docker         # Docker 配置
k8s            # Kubernetes 配置
docs           # 文档
ci             # CI/CD 配置
deps           # 依赖管理
```

#### 按功能域划分
```
auth           # 认证授权
chat           # 聊天功能
webrtc         # 音视频通话
push           # 推送通知
media          # 媒体处理
db             # 数据库
cache          # 缓存
api            # API 接口
ui             # 用户界面
security       # 安全相关
```

### 2.4 提交信息规范要求

#### ✅ 正确示例
```bash
# 新功能
feat(auth-service): add JWT refresh token rotation

# Bug 修复
fix(web-client): resolve memory leak in WebSocket handler

# 带破坏性变更
feat(api)!: change user authentication endpoint response format

BREAKING CHANGE: The /api/auth/login endpoint now returns
user profile in a nested object instead of flat structure.

# 带 Issue 关联
fix(flutter-app): resolve push notification delivery on iOS

Closes #123
Fixes #456

# 多行正文
feat(chat): implement end-to-end encryption for direct messages

- Add E2EE key exchange protocol
- Implement message encryption/decryption
- Add key verification UI
- Update server to handle encrypted message routing

Refs: #789
```

#### ❌ 错误示例
```bash
# 不符合规范
update code                    # 缺少类型和作用域
fix: Fix bug.                  # 添加了句号
feat(auth): Add new feature.   # 首字母大写
Fixed the authentication issue # 不是祈使句
feat(auth):add oauth support   # 冒号后缺少空格
```

### 2.5 提交信息检查

项目使用 `commitlint` 自动验证提交信息格式：

```bash
# 本地安装
npm install -g @commitlint/cli @commitlint/config-conventional

# 配置文件 commitlint.config.js 已在项目根目录
```

---

## 3. 分支管理与保护策略

### 3.1 分支保护规则配置

#### 主分支 (`main`) 保护规则

```yaml
# GitHub Settings -> Branches -> Branch protection rules

分支名称模式: main

保护规则:
  ☑ Require a pull request before merging
    ☑ Require approvals: 2
    ☑ Dismiss stale pull request approvals when new commits are pushed
    ☑ Require review from Code Owners
    
  ☑ Require status checks to pass before merging
    ☑ Require branches to be up to date before merging
    必须通过的状态检查:
      - ci / lint
      - ci / test
      - ci / build
      - security / codeql
      - security / trivy
      
  ☑ Require conversation resolution before merging
  
  ☑ Do not allow bypassing the above settings
  
  ☑ Include administrators
  
  限制推送:
    ☑ Restrict who can push to matching branches
    允许推送的团队: admin-team, release-team
```

#### 开发分支 (`develop`) 保护规则

```yaml
分支名称模式: develop

保护规则:
  ☑ Require a pull request before merging
    ☑ Require approvals: 1
    ☑ Require review from Code Owners
    
  ☑ Require status checks to pass before merging
    必须通过的状态检查:
      - ci / lint
      - ci / test
      
  ☑ Require conversation resolution before merging
  
  限制推送:
    ☑ Restrict who can push to matching branches
    允许推送的团队: dev-team, admin-team
```

### 3.2 CODEOWNERS 配置

创建 `.github/CODEOWNERS` 文件：

```
# CODEOWNERS - 代码审查责任人配置
# 每个文件/目录的修改都需要指定审查人员

# 项目根目录
/                              @mochengjun @admin-team

# Flutter 应用
/apps/flutter_app/             @mobile-team @flutter-experts
/apps/flutter_app/lib/features/auth/ @auth-experts
/apps/flutter_app/lib/features/webrtc/ @webrtc-experts

# Web 客户端
/web-client/                   @frontend-team @react-experts
/web-client/src/core/api/      @api-experts
/web-client/src/presentation/  @ui-experts

# Go 后端服务
/services/auth-service/        @backend-team @auth-experts
/services/push-service/        @backend-team @push-experts
/services/media-proxy/         @backend-team @media-experts
/services/admin-service/       @backend-team @admin-experts

# 基础设施
/deployments/                  @devops-team
/deployments/docker/           @devops-team
/deployments/k8s/              @devops-team @k8s-experts

# CI/CD 配置
/.github/workflows/            @devops-team @ci-experts

# 文档
/docs/                         @documentation-team
/README.md                     @documentation-team

# 安全相关
**/security*                   @security-team
**/auth*                       @security-team @auth-experts
**/*secret*                    @security-team

# 依赖管理
**/go.mod                      @dependency-team
**/go.sum                      @dependency-team
**/pubspec.yaml                @dependency-team
**/package.json                @dependency-team
```

### 3.3 Pull Request 审查流程

#### PR 审查要求

1. **代码审查清单**
   - [ ] 代码逻辑正确，无明显 bug
   - [ ] 遵循项目编码规范
   - [ ] 有充分的单元测试覆盖
   - [ ] 无安全漏洞风险
   - [ ] 文档已更新
   - [ ] 无性能退化

2. **审查人员配置**
   - 主分支 PR: 至少 2 人审查，其中 1 人必须为 Code Owner
   - 开发分支 PR: 至少 1 人审查
   - 安全相关代码: 必须由 @security-team 审查

3. **审查时间要求**
   - P0 (紧急): 4 小时内响应
   - P1 (高优先级): 1 个工作日内响应
   - P2 (中优先级): 2 个工作日内响应
   - P3 (低优先级): 5 个工作日内响应

### 3.4 合并策略

| 分支类型 | 合并方式 | 说明 |
|---------|---------|------|
| `feature/*` → `develop` | **Squash and merge** | 保持历史整洁，将多个提交压缩为一个 |
| `fix/*` → `develop` | **Squash and merge** | 同上 |
| `develop` → `main` | **Merge commit** | 保留完整历史，便于追溯 |
| `hotfix/*` → `main` | **Merge commit** | 保留紧急修复记录 |
| `hotfix/*` → `develop` | **Merge commit** | 同步紧急修复到开发分支 |
| `release/*` → `main` | **Merge commit** | 保留发布历史 |

---

## 4. 标签管理与版本控制

### 4.1 语义化版本控制 (SemVer 2.0.0)

本项目严格遵循 [语义化版本](https://semver.org/) 规范。

#### 版本号格式
```
v[主版本].[次版本].[修订号][-预发布标识].[预发布版本]

示例:
v1.0.0           # 正式版本
v1.1.0           # 新增功能
v1.0.1           # Bug 修复
v2.0.0           # 重大变更
v1.0.0-alpha.1   # 内部测试版
v1.0.0-beta.2    # 公开测试版
v1.0.0-rc.1      # 候选发布版
```

### 4.2 版本号递增规则

| 变更类型 | 版本递增 | 示例 |
|---------|---------|------|
| 不兼容的 API 变更 | 主版本号 | v1.0.0 → v2.0.0 |
| 向后兼容的功能新增 | 次版本号 | v1.0.0 → v1.1.0 |
| 向后兼容的问题修复 | 修订号 | v1.0.0 → v1.0.1 |

### 4.3 预发布版本

| 标识 | 说明 | 使用场景 |
|-----|------|---------|
| `alpha` | 内部测试版 | 功能开发完成，内部验证 |
| `beta` | 公开测试版 | 功能稳定，公开测试 |
| `rc` | 候选发布版 | 准备正式发布，最终验证 |

### 4.4 组件版本同步策略

#### Flutter 应用 (`apps/flutter_app/pubspec.yaml`)

```yaml
# pubspec.yaml
name: sec_chat
version: 1.0.0+1  # 格式: [语义化版本]+[构建号]

# 版本更新脚本
scripts/sync-versions/flutter-version.sh
```

#### Web 客户端 (`web-client/package.json`)

```json
{
  "name": "web-client",
  "version": "0.1.0"
}
```

#### Go 服务 (`services/*/internal/version/version.go`)

```go
package version

var (
    Version   = "1.0.0"
    GitCommit = ""
    BuildTime = ""
)
```

### 4.5 标签命名规范

```bash
# 正式版本
v1.0.0
v1.1.0
v2.0.0

# 预发布版本
v1.0.0-alpha.1
v1.0.0-beta.1
v1.0.0-rc.1

# 组件特定标签
flutter-v1.0.0     # Flutter 应用版本
web-v1.0.0         # Web 客户端版本
auth-v1.0.0        # 认证服务版本
```

### 4.6 版本发布流程

```
1. 创建发布分支
   git checkout develop
   git checkout -b release/v1.0.0

2. 更新版本号
   - 更新 pubspec.yaml
   - 更新 package.json
   - 更新 version.go
   - 更新 CHANGELOG.md

3. 冻结代码
   - 仅允许 bug 修复
   - 更新文档

4. 合并到主分支
   git checkout main
   git merge release/v1.0.0

5. 创建标签
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0

6. 同步到 Gitee
   git push gitee v1.0.0

7. 清理发布分支
   git branch -d release/v1.0.0
```

---

## 5. 双仓库同步方案

### 5.1 仓库配置

```bash
# GitHub (主仓库)
https://github.com/mochengjun/sec-chat

# Gitee (镜像仓库)
https://gitee.com/mochengjun/sec-chat
```

### 5.2 本地 Git 配置

```bash
# 添加远程仓库
cd /path/to/sec-chat

# 查看当前远程仓库
git remote -v

# 添加 GitHub 远程仓库 (如果尚未配置)
git remote add origin https://github.com/mochengjun/sec-chat.git

# 添加 Gitee 远程仓库
git remote add gitee https://gitee.com/mochengjun/sec-chat.git

# 或者使用统一的 pushurl 配置 (推荐)
git remote set-url --add --push origin https://github.com/mochengjun/sec-chat.git
git remote set-url --add --push origin https://gitee.com/mochengjun/sec-chat.git

# 验证配置
git remote -v
```

### 5.3 双仓库同步脚本

项目提供 `scripts/git/sync-remotes.sh` 脚本：

```bash
#!/bin/bash
# 双仓库同步推送脚本
# 用法: ./sync-remotes.sh [branch]

set -e

BRANCH="${1:-$(git branch --show-current)}"

echo "========================================"
echo "同步分支: $BRANCH"
echo "========================================"

# 推送到 GitHub
echo "推送到 GitHub..."
git push origin "$BRANCH"

# 推送到 Gitee
echo "推送到 Gitee..."
git push gitee "$BRANCH"

# 同步标签
echo "同步标签..."
git push origin --tags
git push gitee --tags

echo "========================================"
echo "同步完成!"
echo "GitHub: https://github.com/mochengjun/sec-chat"
echo "Gitee:  https://gitee.com/mochengjun/sec-chat"
echo "========================================"
```

### 5.4 GitHub Actions 自动同步

创建 `.github/workflows/sync-to-gitee.yml`：

```yaml
name: Sync to Gitee

on:
  push:
    branches: [main, develop]
    tags: ['v*']
  workflow_dispatch:

jobs:
  sync:
    name: Sync to Gitee
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Sync to Gitee
        uses: webiny/action-concurrent-sync@v1.0.0
        with:
          sources: |
            [
              {
                "src": "github",
                "srcRepo": "mochengjun/sec-chat",
                "srcBranch": "${{ github.ref_name }}",
                "dest": "gitee",
                "destRepo": "mochengjun/sec-chat",
                "destBranch": "${{ github.ref_name }}"
              }
            ]
          destinations: |
            [
              {
                "name": "gitee",
                "url": "https://gitee.com",
                "token": "${{ secrets.GITEE_TOKEN }}"
              }
            ]
```

### 5.5 手动同步步骤

```bash
# 1. 确保本地代码是最新的
git fetch --all

# 2. 推送当前分支到两个仓库
git push origin main
git push gitee main

# 3. 同步所有标签
git push origin --tags
git push gitee --tags

# 4. 验证同步结果
git ls-remote origin
git ls-remote gitee
```

---

## 6. GitHub Actions 自动化流水线

### 6.1 CI/CD 流程概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        Push / Pull Request                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │   CI 流水线   │ │ Flutter CI   │ │  安全扫描     │
        │  (Go 后端)    │ │  (移动端)     │ │ (CodeQL等)   │
        └──────────────┘ └──────────────┘ └──────────────┘
                │               │               │
                └───────────────┼───────────────┘
                                ▼
                    ┌──────────────────────┐
                    │    所有检查通过？      │
                    └──────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                ▼                               ▼
        ┌──────────────┐                ┌──────────────┐
        │   PR 可合并   │                │   阻止合并    │
        └──────────────┘                └──────────────┘
                │
                ▼ (合并到 main)
        ┌──────────────────────────────────────────┐
        │              CD 流水线                    │
        │  构建镜像 → 推送仓库 → 安全扫描 → 部署    │
        └──────────────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                ▼                               ▼
        ┌──────────────┐                ┌──────────────┐
        │  Staging 环境 │                │ Production   │
        │  (自动部署)   │                │ (标签触发)   │
        └──────────────┘                └──────────────┘
```

### 6.2 工作流文件清单

| 文件名 | 用途 | 触发条件 |
|-------|------|---------|
| `ci.yml` | Go 后端 CI | push/PR 到 main/develop |
| `cd.yml` | 部署流水线 | push 到 main 或 tag v* |
| `flutter.yml` | Flutter CI/CD | push/PR/release |
| `security.yml` | 安全扫描 | push/PR/schedule |
| `sync-to-gitee.yml` | 双仓库同步 | push/手动触发 |
| `release.yml` | 自动发布 | tag v* |
| `web-client.yml` | Web 前端 CI | push/PR |

### 6.3 状态检查要求

#### 必须通过的检查

```yaml
# 主分支合并要求
required_status_checks:
  - ci / lint
  - ci / test
  - ci / build
  - flutter / build-android
  - flutter / build-ios
  - security / codeql
  - security / trivy-scan
```

### 6.4 环境配置

| 环境 | 分支 | 部署方式 | URL |
|-----|------|---------|-----|
| Development | develop | 自动部署 | https://dev.chat.example.com |
| Staging | main | 自动部署 | https://staging.chat.example.com |
| Production | tag v* | 手动触发 | https://chat.example.com |

---

## 7. 仓库配置与模板

### 7.1 Issue 模板

#### Bug 报告模板 (`.github/ISSUE_TEMPLATE/bug_report.yml`)

```yaml
name: Bug 报告
description: 报告一个 Bug 以帮助我们改进
title: "[Bug]: "
labels: ["bug", "triage"]
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        感谢您报告 Bug！请填写以下信息帮助我们定位问题。

  - type: textarea
    id: description
    attributes:
      label: Bug 描述
      description: 清晰描述遇到的问题
      placeholder: "当我尝试...时，发生了..."
    validations:
      required: true

  - type: textarea
    id: steps
    attributes:
      label: 复现步骤
      description: 如何复现这个 Bug
      placeholder: |
        1. 进入 '...'
        2. 点击 '....'
        3. 滚动到 '....'
        4. 看到错误
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: 期望行为
      description: 您期望发生什么
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: 实际行为
      description: 实际发生了什么
    validations:
      required: true

  - type: dropdown
    id: component
    attributes:
      label: 受影响的组件
      multiple: true
      options:
        - Flutter App (Android)
        - Flutter App (iOS)
        - Web Client
        - Auth Service
        - Push Service
        - Media Proxy
        - Admin Service
        - Other
    validations:
      required: true

  - type: input
    id: version
    attributes:
      label: 版本信息
      description: 应用或服务的版本号
      placeholder: "v1.0.0"
    validations:
      required: true

  - type: textarea
    id: logs
    attributes:
      label: 日志信息
      description: 相关的错误日志或截图
      render: shell

  - type: checkboxes
    id: terms
    attributes:
      label: 确认信息
      options:
        - label: 我已经搜索了现有的 Issues，确认这是一个新问题
          required: true
        - label: 我已经尝试使用最新版本，问题仍然存在
          required: false
```

#### 功能请求模板 (`.github/ISSUE_TEMPLATE/feature_request.yml`)

```yaml
name: 功能请求
description: 提出一个新功能建议
title: "[Feature]: "
labels: ["enhancement", "triage"]
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        感谢您的功能建议！请详细描述您的想法。

  - type: textarea
    id: problem
    attributes:
      label: 问题描述
      description: 您希望解决的问题是什么？
      placeholder: "我总是感到困扰，当..."
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: 期望的解决方案
      description: 您希望如何解决这个问题？
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: 替代方案
      description: 您考虑过的其他解决方案

  - type: dropdown
    id: component
    attributes:
      label: 受益组件
      multiple: true
      options:
        - Flutter App
        - Web Client
        - Backend Services
        - Infrastructure
        - All Components

  - type: dropdown
    id: priority
    attributes:
      label: 优先级
      options:
        - Low - 有了更好
        - Medium - 会显著改善体验
        - High - 非常重要
        - Critical - 必须实现
    validations:
      required: true

  - type: textarea
    id: additional
    attributes:
      label: 附加信息
      description: 其他相关信息、截图、参考链接等
```

#### 安全漏洞报告模板 (`.github/ISSUE_TEMPLATE/security_vulnerability.yml`)

```yaml
name: 安全漏洞报告
description: 报告安全漏洞 (敏感信息请发送至 security@example.com)
title: "[Security]: "
labels: ["security", "critical"]
assignees: ["security-team"]
body:
  - type: markdown
    attributes:
      value: |
        ⚠️ **警告**: 如果漏洞涉及敏感信息，请发送邮件至 security@example.com
        而不是在此公开报告。

  - type: textarea
    id: vulnerability
    attributes:
      label: 漏洞描述
      description: 描述发现的安全漏洞
    validations:
      required: true

  - type: dropdown
    id: severity
    attributes:
      label: 严重程度
      options:
        - Critical - 可被直接利用
        - High - 高风险
        - Medium - 中等风险
        - Low - 低风险
    validations:
      required: true

  - type: textarea
    id: impact
    attributes:
      label: 影响范围
      description: 这个漏洞可能造成什么影响？
    validations:
      required: true

  - type: textarea
    id: reproduce
    attributes:
      label: 复现方法
      description: 如何复现这个漏洞
    validations:
      required: true

  - type: textarea
    id: mitigation
    attributes:
      label: 缓解措施
      description: 您建议的修复或缓解方案

  - type: checkboxes
    id: terms
    attributes:
      label: 确认信息
      options:
        - label: 我已阅读并同意负责任披露原则
          required: true
        - label: 我确认这不是敏感信息泄露，可以公开报告
          required: true
```

### 7.2 Pull Request 模板增强版

见 `.github/PULL_REQUEST_TEMPLATE.md`

### 7.3 GitHub 仓库设置清单

#### About 部分
- [ ] Description: "Secure Enterprise Chat - 企业级安全即时通讯系统"
- [ ] Website: https://chat.example.com
- [ ] Topics: `flutter`, `golang`, `react`, `webrtc`, `chat`, `enterprise`, `security`

#### Features
- [ ] ☑ Issues
- [ ] ☑ Projects
- [ ] ☑ Wiki
- [ ] ☑ Discussions
- [ ] ☑ Sponsorships

#### Branches
- [ ] 设置 `main` 分支为默认分支
- [ ] 配置分支保护规则

#### Security
- [ ] 启用 Dependabot alerts
- [ ] 启用 Dependabot security updates
- [ ] 启用 CodeQL scanning
- [ ] 启用 Secret scanning

#### Secrets 配置

```yaml
# GitHub Secrets (Settings -> Secrets and variables -> Actions)

Repository secrets:
  - GITEE_TOKEN          # Gitee 访问令牌
  - KUBE_CONFIG_STAGING  # Staging 环境 kubeconfig
  - KUBE_CONFIG_PRODUCTION # Production 环境 kubeconfig
  - SLACK_WEBHOOK_URL    # Slack 通知 webhook
  - DOCKER_USERNAME      # Docker Hub 用户名
  - DOCKER_PASSWORD      # Docker Hub 密码
  - CODECOV_TOKEN        # Codecov 上传令牌

Environment secrets:
  staging:
    - DATABASE_URL
    - REDIS_URL
    
  production:
    - DATABASE_URL
    - REDIS_URL
```

---

## 8. 团队协作流程

### 8.1 新功能开发流程

```
1. 创建 Issue (功能请求)
   └─> 讨论并确认需求
   └─> 添加标签和指派人员

2. 创建功能分支
   git checkout develop
   git pull origin develop
   git checkout -b feature/user-authentication-flow

3. 本地开发
   └─> 编写代码
   └─> 编写单元测试
   └─> 本地测试通过

4. 提交代码
   git add .
   git commit -m "feat(auth): implement OAuth2.0 authentication"

5. 推送到远程
   git push origin feature/user-authentication-flow

6. 创建 Pull Request
   └─> 填写 PR 模板
   └─> 关联 Issue
   └─> 等待 CI 检查

7. 代码审查
   └─> 审查人员提出意见
   └─> 修改并重新提交

8. 合并到 develop
   └─> Squash merge
   └─> 自动删除功能分支

9. 测试验证
   └─> 在 Staging 环境验证
   └─> 回归测试
```

### 8.2 Bug 修复流程

```
1. 创建 Issue (Bug 报告)
   └─> 详细描述复现步骤
   └─> 添加 bug 标签

2. 确认优先级
   P0 - 立即处理 (阻塞生产环境)
   P1 - 高优先级 (1-2 天内)
   P2 - 中优先级 (1 周内)
   P3 - 低优先级 (安排处理)

3. 创建修复分支
   git checkout develop
   git checkout -b fix/security-vulnerability-in-login

4. 修复并测试
   └─> 修复 bug
   └─> 添加回归测试
   └─> 验证修复有效

5. 提交 PR 并合并
   git commit -m "fix(auth): resolve session fixation vulnerability"

6. 发布到生产环境
   └─> 如果是紧急修复，创建 hotfix 分支
   └─> 否则等待下一个版本发布
```

### 8.3 版本发布流程

```
1. 确认发布内容
   └─> 检查 develop 分支稳定性
   └─> 确认所有功能测试通过

2. 创建发布分支
   git checkout develop
   git checkout -b release/v1.1.0

3. 版本号更新
   └─> 更新 pubspec.yaml
   └─> 更新 package.json
   └─> 更新 version.go
   └─> 更新 CHANGELOG.md

4. 发布前测试
   └─> 完整回归测试
   └─> 性能测试
   └─> 安全扫描

5. 合并到 main
   git checkout main
   git merge release/v1.1.0

6. 创建标签
   git tag -a v1.1.0 -m "Release v1.1.0"

7. 推送并触发部署
   git push origin main
   git push origin v1.1.0

8. 同步到 Gitee
   git push gitee main
   git push gitee v1.1.0

9. 发布说明
   └─> 在 GitHub 创建 Release
   └─> 发布公告
```

### 8.4 紧急修复流程 (Hotfix)

```
1. 发现生产环境严重问题
   └─> 立即创建 P0 Issue

2. 创建 hotfix 分支
   git checkout main
   git checkout -b hotfix/v1.0.1-critical-security-patch

3. 快速修复
   └─> 最小化修改
   └─> 快速测试

4. 合并到 main
   git checkout main
   git merge hotfix/v1.0.1-critical-security-patch

5. 创建标签并部署
   git tag -a v1.0.1 -m "Hotfix v1.0.1"
   git push origin main
   git push origin v1.0.1

6. 同步回 develop
   git checkout develop
   git merge hotfix/v1.0.1-critical-security-patch
   git push origin develop

7. 同步到 Gitee
   git push gitee main --tags
   git push gitee develop
```

---

## 附录

### A. 相关文件清单

| 文件路径 | 用途 |
|---------|------|
| `.github/workflows/ci.yml` | Go 后端 CI 流水线 |
| `.github/workflows/cd.yml` | 部署流水线 |
| `.github/workflows/flutter.yml` | Flutter CI/CD |
| `.github/workflows/security.yml` | 安全扫描 |
| `.github/workflows/sync-to-gitee.yml` | 双仓库同步 |
| `.github/workflows/release.yml` | 自动发布 |
| `.github/workflows/web-client.yml` | Web 前端 CI |
| `.github/CODEOWNERS` | 代码审查责任人 |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR 模板 |
| `.github/ISSUE_TEMPLATE/*.yml` | Issue 模板 |
| `scripts/git/sync-remotes.sh` | 双仓库同步脚本 |
| `commitlint.config.js` | 提交信息验证配置 |
| `CHANGELOG.md` | 变更日志 |

### B. 参考文档

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [GitFlow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**文档维护**: 本文档随项目发展持续更新，如有疑问请联系 @mochengjun
