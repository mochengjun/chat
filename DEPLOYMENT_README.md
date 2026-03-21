# 企业安全聊天系统 - 完整部署指南

## 📋 项目概述

这是一个企业级安全聊天系统，采用现代化技术栈构建，具备以下特性：

- **安全性**: 端到端加密、多因素认证、消息自毁
- **跨平台**: 支持Windows、Android、iOS、macOS、Web
- **实时通信**: WebSocket长连接、消息即时推送
- **网络优化**: ZeroTier虚拟网络、Docker代理配置
- **智能配置**: 自动网络检测、动态代理设置

## 🚀 快速开始

### 1. 环境准备

```bash
# 克隆项目
git clone <repository-url>
cd secure-enterprise-chat

# 安装依赖
choco install zerotier-one docker-desktop flutter -y
```

### 2. 网络配置

```batch
# 1. 连接ZeroTier网络（管理员权限）
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" join 6AB565387A193124

# 2. 在 https://my.zerotier.com 授权节点

# 3. 配置Docker代理
powershell -ExecutionPolicy Bypass -File configure_docker_zerotier.ps1
```

### 3. 启动服务

```bash
# 启动基础设施
cd deployments/docker
docker-compose up -d

# 启动认证服务
cd ../../services/auth-service
go run cmd/main.go

# 构建客户端
cd ../../apps/flutter_app
flutter build windows --release
```

## 🛠️ 开发工具

### 自动化脚本

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `validate_deployment.bat` | 部署环境验证 | 生产环境部署前检查 |
| `test_installer.bat` | 安装包功能测试 | 构建完成后验证 |
| `build-windows.bat` | Windows客户端构建 | 发布新版本 |
| `build-android-full.bat` | Android完整构建 | 移动端发布 |
| `connect_to_zerotier_admin.bat` | ZeroTier网络连接 | 网络配置初始化 |

### 网络诊断命令

```powershell
# 检查网络状态
validate_deployment.bat

# 测试API连接
curl http://172.25.118.254:8081/health

# 验证ZeroTier连接
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks
```

## 📱 客户端配置

### Windows客户端

**网络配置集成**:
- 自动检测ZeroTier网络连接
- 动态API服务器地址配置
- Docker代理设置验证
- 网络诊断工具集成

**构建命令**:
```batch
# 完整测试构建
test_installer.bat

# 生成便携包
build-windows.bat
```

### Android客户端

**增强的网络支持**:
- ZeroTier VPN权限配置
- 网络安全策略更新
- Docker镜像源配置
- 完整的网络配置包

**构建命令**:
```batch
# 构建完整Android包
build-android-full.bat
```

生成的包包含：
- APK文件
- AAB文件  
- ZeroTier配置指南
- Docker代理说明
- 网络安全配置

## 📦 部署架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   客户端应用    │◄──►│  ZeroTier网络   │◄──►│   服务端集群    │
│  (Flutter)      │    │   (虚拟网络)    │    │  (Docker容器)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
       │                       │                       │
       ▼                       ▼                       ▼
  ┌─────────┐           ┌──────────┐           ┌─────────────┐
  │本地网络 │           │172.25.118│           │  内网服务   │
  └─────────┘           └──────────┘           │ - PostgreSQL│
                                                │ - Redis     │
                                                │ - Auth API  │
                                                └─────────────┘
```

## 🔧 核心配置

### 网络配置参数

```yaml
# ZeroTier配置
network_id: 6AB565387A193124
gateway_ip: 172.25.118.254
node_id: b239bac9cc  # 当前节点ID
proxy_port: 9993

# Docker代理配置
http_proxy: http://172.25.118.254:9993
https_proxy: http://172.25.118.254:9993
no_proxy: localhost,127.0.0.1,hubproxy.docker.internal

# 镜像加速器
mirrors:
  - https://docker.mirrors.ustc.edu.cn
  - https://hub-mirror.c.163.com
  - https://mirror.baidubce.com

# 客户端网络配置
windows_client_ip: 172.25.118.254
api_port: 8081
websocket_port: 8082
```

### 客户端网络配置

**Windows客户端**:
- 自动检测ZeroTier网络连接状态
- 动态API服务器地址配置(172.25.118.254:8081)
- 集成Docker代理设置验证
- 网络诊断工具集成
- 便携式ZIP包生成支持

**Android客户端**:
- VPN权限支持(BIND_VPN_SERVICE)
- 网络安全策略配置(network_security_config.xml)
- 支持ZeroTier网络段访问
- Docker镜像源配置集成
- 多网络环境自适应

### 服务端口映射

| 服务 | 容器端口 | 主机端口 | 用途 |
|------|----------|----------|------|
| PostgreSQL | 5432 | 5432 | 数据库存储 |
| Redis | 6379 | 6379 | 缓存服务 |
| Auth Service | 8081 | 8081 | 认证API |
| Nginx | 80/443 | 80/443 | 反向代理 |

## 🎯 验证清单

### 部署前检查
- [ ] ZeroTier网络连接正常(网络ID: 6AB565387A193124)
- [ ] Docker代理配置正确(172.25.118.254:9993)
- [ ] 镜像加速器配置生效
- [ ] 基础设施服务启动(数据库、缓存、API)
- [ ] API接口响应正常(http://172.25.118.254:8081/health)
- [ ] 客户端网络配置验证通过
- [ ] Windows安装包功能测试完成
- [ ] Android客户端构建验证通过

### 功能测试
- [ ] 用户注册/登录功能
- [ ] 实时消息收发
- [ ] 群组聊天功能
- [ ] 文件传输功能
- [ ] 音视频通话
- [ ] 网络配置自适应(ZeroTier/Docker代理)
- [ ] 跨平台兼容性测试
- [ ] 离线消息同步功能

### 性能监控
- [ ] 系统资源使用率
- [ ] 网络延迟测试
- [ ] 并发用户测试
- [ ] 错误日志监控

## 📊 监控与维护

### 日志查看

```bash
# 查看服务日志
docker-compose logs -f

# 查看特定服务
docker-compose logs -f auth-service

# 客户端日志位置
%LOCALAPPDATA%\SecChat\logs\  # Windows
/sdcard/Android/data/com.example.sec_chat/files/  # Android
```

### 健康检查

```bash
# 服务健康状态
curl http://localhost:8081/health

# 数据库连接测试
docker-compose exec postgres pg_isready

# Redis连接测试
docker-compose exec redis redis-cli ping

# 网络诊断
validate_deployment.bat
```

## 🔒 安全配置

### 访问控制
- 用户认证采用JWT Token
- 敏感操作需要二次验证
- 设备绑定防未授权访问

### 数据保护
- 消息传输端到端加密
- 数据库存储加密
- 定期自动清理过期数据

### 网络安全
- ZeroTier网络隔离
- 防火墙规则配置
- 定期安全扫描

## 🆘 故障排除

### 常见问题

**Q: ZeroTier连接失败**
A: 检查管理员权限，确认在ZeroTier Central已授权节点

**Q: Docker镜像拉取超时**
A: 验证代理配置，重启Docker服务

**Q: 客户端无法连接服务器**
A: 检查网络配置，验证API服务状态

**Q: Android应用网络异常**
A: 确认ZeroTier VPN已连接，检查网络安全配置

**Q: 构建失败**
A: 清理构建缓存，更新依赖包

### 支持资源

- 📖 [详细文档](./docs/)
- 🐛 [问题反馈](https://github.com/your-org/secure-chat/issues)
- 💬 [技术支持](mailto:support@company.com)

## 📱 移动端特殊配置

### Android配置详情

**权限要求**:
- INTERNET: 网络访问
- ACCESS_NETWORK_STATE: 网络状态检测
- BIND_VPN_SERVICE: ZeroTier VPN支持

**网络安全配置**:
- 支持ZeroTier网络段(172.25.118.0/24)
- Docker容器网络支持
- 国内镜像源配置

### iOS配置说明

iOS版本需要通过企业证书或App Store分发，配置要求与Android类似。

---

**版本**: 1.0.0  
**最后更新**: 2026年3月  
**许可证**: 企业专有