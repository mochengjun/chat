# 智能编译缓存工具

## 概述

本工具为企业级安全聊天应用提供智能依赖缓存管理,支持 Flutter、Go、Node.js 多技术栈的统一缓存管理。

## 功能特性

### 1. 统一缓存仓库
- 在本地建立 `.cache` 或 `vendor` 目录作为统一缓存仓库
- 跨项目共享依赖项,避免重复下载
- 支持离线构建模式

### 2. 多技术栈支持
- **Flutter/Dart**: `pubspec.yaml` 依赖缓存
- **Go**: `go.mod` / `go.sum` 模块缓存
- **Node.js**: `package.json` 包缓存

### 3. 增量式缓存策略
- 版本匹配验证
- 缓存失效检测
- 跨平台兼容性支持

### 4. 记忆功能
- 依赖项历史版本追踪
- 下载时间戳记录
- 项目间共享依赖识别

## 快速开始

### 安装

```bash
# 将脚本添加到 PATH 或直接调用
cd scripts/cache-manager
```

### 基本用法

```bash
# 检查所有项目的依赖缓存状态
python cache_manager.py check

# 预下载所有依赖到本地缓存
python cache_manager.py sync

# 清理缓存
python cache_manager.py clean

# 查看缓存统计信息
python cache_manager.py stats
```

### 集成到构建脚本

在现有的 `build-*.bat` 或 `build-*.sh` 脚本中添加:

```bash
# 构建前同步缓存
python scripts/cache-manager/cache_manager.py sync --project flutter

# 或使用离线模式
python scripts/cache-manager/cache_manager.py sync --offline --project flutter
```

## 缓存目录结构

```
.cache/
├── flutter/
│   ├── pub-cache/           # Flutter/Dart 包缓存
│   └── gradle-cache/        # Gradle 依赖缓存
├── go/
│   └── mod-cache/           # Go 模块缓存
├── nodejs/
│   └── npm-cache/           # NPM 包缓存
├── index.json               # 缓存索引
└── history.json             # 历史记录
```

## 配置文件

缓存工具会读取项目根目录的 `cache-config.json`:

```json
{
  "cache_dir": ".cache",
  "flutter": {
    "enabled": true,
    "pub_cache": true,
    "gradle_cache": true
  },
  "go": {
    "enabled": true,
    "mod_cache": true,
    "proxy": "https://goproxy.cn,direct"
  },
  "nodejs": {
    "enabled": true,
    "npm_cache": true,
    "registry": "https://registry.npmmirror.com"
  },
  "offline_mode": false,
  "max_cache_size_gb": 10,
  "cache_expiry_days": 30
}
```

## 命令详解

### check - 检查缓存状态

```bash
python cache_manager.py check [选项]

选项:
  --project {flutter,go,nodejs,all}   指定项目类型 (默认: all)
  --verbose                           显示详细信息
```

### sync - 同步缓存

```bash
python cache_manager.py sync [选项]

选项:
  --project {flutter,go,nodejs,all}   指定项目类型 (默认: all)
  --offline                           使用离线模式
  --force                             强制重新下载
```

### clean - 清理缓存

```bash
python cache_manager.py clean [选项]

选项:
  --project {flutter,go,nodejs,all}   指定项目类型 (默认: all)
  --all                               清理所有缓存
  --older-than DAYS                   清理超过指定天数的缓存
```

### stats - 缓存统计

```bash
python cache_manager.py stats
```

## 环境变量

工具支持以下环境变量:

- `CACHE_DIR`: 缓存目录路径 (优先级高于配置文件)
- `FLUTTER_PUB_CACHE`: Flutter Pub 缓存路径
- `GOPATH`: Go 工作空间路径
- `NPM_CONFIG_CACHE`: NPM 缓存路径
- `OFFLINE_MODE`: 离线模式标志

## 最佳实践

1. **首次构建**: 运行 `cache_manager.py sync` 预下载所有依赖
2. **日常开发**: 使用 `--offline` 标志加速构建
3. **定期清理**: 每周运行 `cache_manager.py clean --older-than 30`
4. **CI/CD 集成**: 在流水线中缓存 `.cache` 目录

## 故障排查

### 缓存损坏

```bash
# 清理并重建缓存
python cache_manager.py clean --all
python cache_manager.py sync --force
```

### 版本冲突

```bash
# 检查具体依赖版本
python cache_manager.py check --verbose
```

### 离线模式失败

确保之前运行过在线模式的 sync 命令,依赖已完整缓存。

## 许可证

企业内部使用
