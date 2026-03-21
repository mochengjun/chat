# 项目路径映射对照表

## 源代码环境 (开发环境)
- **项目根目录**: `c:\Users\MCJ\source\quest\chat\`
- **服务源码**: `c:\Users\MCJ\source\quest\chat\services\auth-service\`
- **数据库文件**: `c:\Users\MCJ\source\quest\chat\auth.db`
- **配置文件**: `c:\Users\MCJ\source\quest\chat\deployments\docker\.env.production`

## 部署环境 (容器环境)
- **容器工作目录**: `/app/`
- **可执行文件**: `/app/main`
- **数据库目录**: `/app/data/`
- **日志目录**: `/app/logs/`
- **上传目录**: `/app/uploads/`
- **配置目录**: `/app/config/`

## Docker 卷挂载映射
```yaml
volumes:
  # 日志文件持久化
  - ../logs:/app/logs
  # 上传文件持久化  
  - ../uploads:/app/uploads
  # 数据文件持久化
  - ../data:/app/data
  # 数据库文件直接映射
  - ../../auth.db:/app/data/auth.db
  - ../../auth.db-shm:/app/data/auth.db-shm
  - ../../auth.db-wal:/app/data/auth.db-wal
```

## 环境变量配置
```bash
# 容器内相对路径
DB_PATH=./data/auth.db
LOG_DIR=./logs
UPLOAD_DIR=./uploads
CONFIG_DIR=./config
```

## 编译输出路径
- **编译命令**: `go build -o main cmd/main.go`
- **输出位置**: 项目根目录下的 `main` 可执行文件
- **Docker构建**: COPY 主目录下的 `main` 到容器 `/app/main`

## 注意事项
1. 绝对不要在容器内直接修改源代码
2. 开发时修改源码文件，重新构建镜像
3. 数据库文件通过卷挂载保持持久化
4. 配置文件通过环境变量注入
5. 日志和上传文件通过卷挂载持久化