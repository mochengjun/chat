# Changelog

本项目的所有重要变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [Unreleased]

### 计划新增
- WebRTC 多人视频会议功能
- 端到端加密消息撤回
- 消息已读回执增强
- 管理后台增强

### 计划改进
- 性能优化：大文件上传分片
- 体验优化：消息加载动画

---

## [1.0.0] - 2025-03-17

### 🎉 首次发布

#### 新增功能

##### Flutter 应用
- 用户认证：登录、注册、密码重置
- 即时通讯：单聊、群聊、消息发送/接收
- 音视频通话：WebRTC 点对点通话
- 推送通知：Firebase 云消息推送
- 本地存储：SQLite 消息缓存
- 生物识别：指纹/面容登录
- 国际化：中英文支持

##### Web 客户端
- 响应式界面：适配桌面和移动端
- 消息功能：文本、图片、文件消息
- 用户管理：个人信息、好友列表
- 群组管理：创建、加入、退出群组
- 主题切换：亮色/暗色模式

##### 后端服务
- 认证服务 (auth-service)
  - JWT 认证授权
  - 用户注册登录
  - 权限管理
  - WebSocket 连接管理
- 推送服务 (push-service)
  - 多平台推送支持
  - 推送模板管理
- 媒体代理 (media-proxy)
  - 文件上传下载
  - 图片处理
  - 视频转码
- 管理服务 (admin-service)
  - 用户管理
  - 系统配置
  - 日志审计

##### 基础设施
- Docker 容器化部署
- Kubernetes 编排配置
- Nginx 反向代理
- Prometheus + Grafana 监控
- 自动化 CI/CD 流水线

#### 技术栈
- **前端**: Flutter 3.16+, React 19, TypeScript 5.9
- **后端**: Go 1.23, Gin, GORM
- **数据库**: PostgreSQL 16, Redis 7
- **基础设施**: Docker, Kubernetes, Nginx
- **监控**: Prometheus, Grafana, Loki

---

## 版本说明

### 版本号格式

本项目严格遵循 [语义化版本控制 2.0.0](https://semver.org/lang/zh-CN/) 标准：

```
v[主版本].[次版本].[修订号][-预发布标识]
```

**格式示例：**
- `v1.0.0` - 正式版本
- `v1.2.0` - 功能更新
- `v1.2.3` - 问题修复
- `v2.0.0-alpha.1` - 预发布版本

### 版本递增规则

| 版本位 | 递增条件 | 示例 |
|--------|---------|------|
| **主版本 (MAJOR)** | 进行不兼容的 API 变更时 | `v1.x.x` → `v2.0.0` |
| **次版本 (MINOR)** | 以向后兼容的方式添加功能时 | `v1.0.x` → `v1.1.0` |
| **修订号 (PATCH)** | 进行向后兼容的问题修复时 | `v1.0.0` → `v1.0.1` |

### 预发布标识

预发布版本用于在正式版本发布前进行测试：

| 标识 | 含义 | 用途 |
|------|------|------|
| `alpha` | 内部测试版本 | 功能开发阶段，不稳定 |
| `beta` | 公开测试版本 | 功能冻结，主要测试 Bug |
| `rc` | 候选发布版本 | 预发布候选，接近正式版 |

**预发布版本示例：**
- `v1.0.0-alpha.1` → `v1.0.0-alpha.2` → `v1.0.0-beta.1` → `v1.0.0-rc.1` → `v1.0.0`

### 变更日志格式规范

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 格式：

#### 分类标签

- `### Added` - 新增功能
- `### Changed` - 变更
- `### Deprecated` - 弃用
- `### Removed` - 移除
- `### Fixed` - 修复
- `### Security` - 安全相关

#### 版本比较链接

每个版本标题应链接到对应的 Git 标签比较页面：

```markdown
## [1.0.0] - 2025-03-17
[1.0.0]: https://github.com/mochengjun/sec-chat/compare/v0.9.0...v1.0.0
```

---

## 仓库地址

- **GitHub**: https://github.com/mochengjun/sec-chat
- **Gitee**: https://gitee.com/mochengjun/sec-chat

---

## 贡献者

感谢所有贡献者的付出！

<!-- 贡献者列表将由 GitHub Actions 自动更新 -->

---

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

---

## 版本发布流程

### 发布前准备

1. 确保所有功能已合并到 `develop` 分支
2. 更新本文件，将 `[Unreleased]` 的变更整理到新版本
3. 更新各模块版本配置文件

### 创建发布

```bash
# 1. 创建发布分支
git checkout -b release/v1.1.0

# 2. 更新版本号和 CHANGELOG
# ... 编辑文件 ...

# 3. 提交更改
git add -A
git commit -m "chore(release): prepare for v1.1.0"

# 4. 合并到 main 并打标签
git checkout main
git merge release/v1.1.0
git tag -a v1.1.0 -m "Release version 1.1.0"
git push upstream main --tags

# 5. 合并回 develop
git checkout develop
git merge release/v1.1.0
git push upstream develop
```

### 版本对比链接

- [Unreleased]: https://github.com/mochengjun/sec-chat/compare/v1.0.0...HEAD
- [1.0.0]: https://github.com/mochengjun/sec-chat/releases/tag/v1.0.0

---

> 此 CHANGELOG 由项目维护者手动维护，遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范。
> 如需更新，请提交 PR 或联系维护者 @mochengjun。
