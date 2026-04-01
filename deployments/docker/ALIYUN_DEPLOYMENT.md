# ============================================================
# 阿里云服务器部署指南
# 服务器IP: 8.130.55.126
# ============================================================

## 一、前置条件

### 1. 服务器要求
- 操作系统: Ubuntu 20.04+ 或 CentOS 7+
- 内存: 至少 2GB
- 磁盘: 至少 20GB
- Docker 和 Docker Compose 已安装

### 2. 安装 Docker (如未安装)
```bash
# Ubuntu
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## 二、阿里云安全组配置

### 登录阿里云控制台配置安全组规则:

1. 登录 [阿里云控制台](https://ecs.console.aliyun.com/)
2. 进入 云服务器ECS -> 网络与安全 -> 安全组
3. 找到服务器对应的安全组，点击"配置规则"
4. 添加以下入方向规则:

| 协议 | 端口范围 | 授权对象 | 说明 |
|------|----------|----------|------|
| TCP | 22 | 0.0.0.0/0 | SSH |
| TCP | 80 | 0.0.0.0/0 | HTTP |
| TCP | 443 | 0.0.0.0/0 | HTTPS |
| TCP | 8081 | 0.0.0.0/0 | API |

## 三、服务器防火墙配置

```bash
# 上传并运行防火墙配置脚本
chmod +x setup-firewall.sh
sudo ./setup-firewall.sh
```

或手动配置:

```bash
# 使用 firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8081/tcp
sudo firewall-cmd --reload

# 使用 ufw (Ubuntu)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8081/tcp
sudo ufw --force enable
```

## 四、部署应用

### 1. 上传项目到服务器

```bash
# 方式1: 使用 git clone (推荐)
ssh root@8.130.55.126
cd /opt
git clone <your-repo-url> chat
cd chat

# 方式2: 使用 scp 上传
scp -r . root@8.130.55.126:/opt/chat/
```

### 2. 配置环境变量

```bash
cd /opt/chat/deployments/docker

# 复制环境变量模板
cp .env.example .env

# 编辑环境变量
nano .env
```

**重要配置项:**

```bash
# 服务器配置
SERVER_HOST=8.130.55.126
ALLOWED_ORIGINS=http://8.130.55.126,http://8.130.55.126:80

# 数据库密码 (必须修改!)
POSTGRES_PASSWORD=你的强密码

# Redis 密码 (必须修改!)
REDIS_PASSWORD=你的强密码

# JWT 密钥 (必须修改! 至少32字符)
JWT_SECRET=你的JWT密钥至少32个字符

# 生成安全的 JWT 密钥
# openssl rand -base64 64
```

### 3. 构建和启动服务

```bash
# 初始化部署
./deploy.sh init

# 构建镜像
./deploy.sh build

# 启动服务
./deploy.sh start

# 查看服务状态
./deploy.sh status
```

### 4. 检查服务健康状态

```bash
# 查看日志
./deploy.sh logs

# 检查特定服务
docker compose ps
docker compose logs auth-service
```

## 五、验证部署

### 1. 本地验证

```bash
# 在服务器上执行
curl http://localhost/health
curl http://localhost:8081/health
curl http://localhost/nginx-health
```

### 2. 外网访问测试

从本地电脑浏览器访问:

- API健康检查: http://8.130.55.126/health
- API端口: http://8.130.55.126:8081/health
- Nginx状态: http://8.130.55.126/nginx-health

### 3. WebSocket 连接测试

```javascript
// 在浏览器控制台测试
const ws = new WebSocket('ws://8.130.55.126/api/v1/ws');
ws.onopen = () => console.log('WebSocket 连接成功');
ws.onerror = (e) => console.error('WebSocket 错误:', e);
```

## 六、常见问题排查

### 1. 无法访问服务

```bash
# 检查服务状态
docker compose ps

# 检查端口监听
netstat -tlnp | grep -E '80|8081|443'

# 检查防火墙
firewall-cmd --list-ports
# 或
ufw status

# 检查阿里云安全组
# 确保在控制台已开放端口
```

### 2. 容器无法启动

```bash
# 查看详细日志
docker compose logs auth-service

# 检查数据库连接
docker compose exec postgres pg_isready

# 检查 Redis 连接
docker compose exec redis redis-cli ping
```

### 3. WebSocket 连接失败

```bash
# 检查 nginx 配置
docker compose exec nginx nginx -t

# 查看 nginx 错误日志
docker compose logs nginx | grep -i error
```

## 七、服务管理命令

```bash
# 启动服务
./deploy.sh start

# 停止服务
./deploy.sh stop

# 重启服务
./deploy.sh restart

# 查看日志
./deploy.sh logs
./deploy.sh logs auth-service

# 数据库备份
./deploy.sh backup

# 更新部署
./deploy.sh update
```

## 八、访问地址汇总

| 服务 | 地址 | 说明 |
|------|------|------|
| HTTP访问 | http://8.130.55.126 | 通过Nginx访问 |
| API直接访问 | http://8.130.55.126:8081 | 直接访问API |
| 健康检查 | http://8.130.55.126/health | 服务健康状态 |
| WebSocket | ws://8.130.55.126/api/v1/ws | WebSocket连接 |

## 九、安全建议

1. **修改默认密码**: 确保所有密码都使用强密码
2. **启用 HTTPS**: 配置SSL证书，使用HTTPS
3. **限制访问**: 考虑限制管理端口的访问IP
4. **定期备份**: 设置数据库自动备份
5. **监控日志**: 定期检查异常访问日志
