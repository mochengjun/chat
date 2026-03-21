# Google Cloud Console OAuth 配置详细步骤

## 📋 配置前准备

### 需要准备的信息
- Google 账号（建议使用企业邮箱）
- 项目名称：`sec-chat-oauth` 或您的企业命名
- 生产域名：`yourcompany.com`
- 开发端口：`8081` (auth-service)

---

## 🚀 步骤 1：创建 Google Cloud 项目

### 1.1 访问 Google Cloud Console
1. 打开浏览器，访问：https://console.cloud.google.com/
2. 使用您的 Google 账号登录

### 1.2 创建新项目
1. 点击顶部导航栏的 **项目选择器**（显示当前项目名称的下拉菜单）
2. 在弹出的对话框中，点击右上角的 **"新建项目"**
3. 填写项目信息：
   ```
   项目名称：sec-chat-oauth
   组织：（如果有企业组织，选择它；否则留空）
   位置：（默认即可）
   ```
4. 点击 **"创建"**
5. 等待约 30 秒，项目创建完成
6. 点击顶部的 **"选择项目"**，选择刚创建的项目

### ✅ 验证步骤
- [ ] 项目创建成功
- [ ] 已选择新创建的项目
- [ ] 顶部显示项目名称 `sec-chat-oauth`

---

## 🔐 步骤 2：配置 OAuth 同意屏幕

**重要**：必须先配置 OAuth 同意屏幕才能创建凭据！

### 2.1 进入 OAuth 同意屏幕配置
1. 在左侧菜单中，点击 **"API 和服务"** → **"OAuth 同意屏幕"**
2. 或者直接访问：https://console.cloud.google.com/apis/credentials/consent

### 2.2 选择用户类型

#### 选项 A：内部模式（推荐企业使用）
```
✅ 内部
仅限 Google Workspace 组织内的用户使用

优点：
- 仅企业内部员工可访问
- 无需 Google 审核
- 更安全

要求：需要 Google Workspace 账户
```

#### 选项 B：外部模式
```
⭕ 外部
任何 Google 账户都可以使用

适用场景：
- 没有 Google Workspace
- 需要允许外部用户

注意：
- 发布前有测试用户限制（100个）
- 发布后需要 Google 审核
```

**建议**：如果您有 Google Workspace，选择 **"内部"**；否则选择 **"外部"**

3. 选择后点击 **"创建"**

### 2.3 配置应用信息（OAuth 同意屏幕）

#### 第一页：应用信息

| 字段 | 值 | 说明 |
|------|-----|------|
| **应用名称** | `企业安全聊天` | 显示给用户的名称 |
| **用户支持电子邮件地址** | 选择您的邮箱 | 用户问题联系邮箱 |
| **应用徽标** | 上传 128x128 PNG | 可选，建议上传企业 Logo |

**应用网域**（可选但建议填写）：
```
应用首页链接：https://chat.yourcompany.com
应用隐私权政策链接：https://chat.yourcompany.com/privacy
应用服务条款链接：https://chat.yourcompany.com/terms
```

**已授权网域**（重要！）：
```
yourcompany.com
localhost
```
> 点击"添加网域"，添加您的生产域名和 localhost

**开发者联系信息**：
```
电子邮件地址：your-email@yourcompany.com
```

4. 点击 **"保存并继续"**

### 2.4 配置作用域（Scopes）

1. 点击 **"添加或移除作用域"**
2. 在过滤器中搜索，勾选以下作用域：

```
✅ .../auth/userinfo.email        - 查看您的主要 Google 课后电子邮件地址
✅ .../auth/userinfo.profile      - 查看您的个人信息，包括您公开的个人资料信息
✅ openid                         - 将您的姓名和电子邮件地址与应用关联
```

3. 点击 **"更新"**
4. 点击 **"保存并继续"**

### 2.5 测试用户（仅外部模式）

如果是 **外部模式** 且应用未发布，需要添加测试用户：

1. 点击 **"添加用户"**
2. 输入测试用的 Google 邮箱地址（每行一个）
3. 点击 **"保存并继续"**

> 注意：测试用户最多 100 个，发布后所有 Google 用户都可以使用

### 2.6 审核并完成

1. 检查所有配置是否正确
2. 点击 **"返回信息中心"**

### ✅ 验证步骤
- [ ] OAuth 同意屏幕已配置
- [ ] 应用名称显示正确
- [ ] 已添加授权网域（包括 localhost）
- [ ] 已选择必需的作用域

---

## 🔑 步骤 3：创建 OAuth 2.0 客户端凭据

### 3.1 进入凭据页面
1. 在左侧菜单中，点击 **"API 和服务"** → **"凭据"**
2. 或直接访问：https://console.cloud.google.com/apis/credentials

### 3.2 创建 OAuth 客户端 ID
1. 点击顶部菜单栏的 **"创建凭据"**
2. 选择 **"OAuth 客户端 ID"**

### 3.3 配置 OAuth 客户端

**应用类型**：
```
选择：Web 应用
```

**名称**：
```
Sec-Chat Web Client
```

#### 已授权的 JavaScript 来源

点击"添加 URI"，添加以下来源：

```
# 开发环境
http://localhost:3000
http://localhost:5173
http://localhost:8081

# 生产环境（替换为您的实际域名）
https://chat.yourcompany.com
https://api.chat.yourcompany.com
```

> 这些是允许发起 OAuth 请求的源域名

#### 已授权的重定向 URI（关键！）

点击"添加 URI"，添加以下重定向 URI：

```
# 开发环境
http://localhost:8081/api/v1/auth/oauth/google/callback
http://localhost:3000/auth/callback
http://localhost:5173/auth/callback

# 生产环境
https://chat.yourcompany.com/api/v1/auth/oauth/google/callback
https://api.chat.yourcompany.com/api/v1/auth/oauth/google/callback
```

**⚠️ 重要提示**：
- 重定向 URI 必须 **完全匹配** 代码中的配置
- 包括协议（http/https）、域名、端口、路径
- 不能有末尾斜杠
- 大小写敏感

3. 点击 **"创建"**

### 3.4 保存凭据信息

创建成功后，会显示一个对话框：

```
OAuth 客户端已创建

您的客户端 ID
123456789012-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com

您的客户端密钥
GOCSPX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ 立即保存这些信息！**

1. 点击 **"下载 JSON"** 按钮，保存凭据文件
2. 或者复制以下信息：
   - **客户端 ID** → 用于环境变量 `GOOGLE_CLIENT_ID`
   - **客户端密钥** → 用于环境变量 `GOOGLE_CLIENT_SECRET`

3. 点击 **"确定"**

### ✅ 验证步骤
- [ ] OAuth 客户端已创建
- [ ] 已保存客户端 ID
- [ ] 已保存客户端密钥
- [ ] 已下载 JSON 凭据文件（可选但建议）
- [ ] 重定向 URI 已正确配置

---

## 🔒 步骤 4：安全配置凭据

### 4.1 凭据安全存储

#### 开发环境
```bash
# 进入项目目录
cd services/auth-service

# 复制示例文件
cp .env.oauth.example .env.local

# 编辑 .env.local（不要提交到 Git）
nano .env.local  # 或使用您喜欢的编辑器
```

填入真实凭据：
```bash
GOOGLE_CLIENT_ID=123456789012-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GOOGLE_REDIRECT_URL=http://localhost:8081/api/v1/auth/oauth/google/callback
```

#### 生产环境

**推荐使用密钥管理服务**：

##### 选项 A：Google Secret Manager
```bash
# 创建密钥
echo -n "your-client-id" | gcloud secrets create google-client-id --data-file=-

echo -n "your-client-secret" | gcloud secrets create google-client-secret --data-file=-
```

##### 选项 B：AWS Secrets Manager
```bash
aws secretsmanager create-secret \
  --name auth-service/oauth \
  --secret-string '{"google_client_id":"...","google_client_secret":"..."}'
```

##### 选项 C：HashiCorp Vault
```bash
vault kv put secret/auth-service/oauth \
  google_client_id="..." \
  google_client_secret="..."
```

### 4.2 凭据轮换策略

建议定期轮换凭据（每 90 天）：

1. 在 Google Cloud Console 创建新的 OAuth 客户端凭据
2. 更新环境变量或密钥存储
3. 重启服务
4. 删除旧凭据

### 4.3 .gitignore 配置

确保以下内容在 `.gitignore` 中：

```gitignore
# Environment variables
.env
.env.local
.env.*.local
*.env

# Secrets
secrets/
.secrets/

# Google credentials
*credentials*.json
client_secret*.json
```

---

## 📊 步骤 5：验证配置

### 5.1 检查 OAuth 同意屏幕

1. 返回 **"OAuth 同意屏幕"** 页面
2. 确认发布状态：
   - **内部模式**：显示"仅供内部使用"
   - **外部模式**：
     - 测试中：显示"正在测试"
     - 发布后：显示"已投入生产"

### 5.2 检查凭据

1. 返回 **"凭据"** 页面
2. 确认 OAuth 2.0 客户端 ID 已创建
3. 点击编辑图标，检查：
   - 已授权的 JavaScript 来源
   - 已授权的重定向 URI

### 5.3 测试配置

使用 OAuth 2.0 Playground 测试：
1. 访问：https://developers.google.com/oauthplayground/
2. 配置自己的 OAuth 凭据
3. 测试授权流程

---

## 🎯 快速配置检查清单

### Google Cloud Console
- [ ] 项目已创建并选中
- [ ] OAuth 同意屏幕已配置
  - [ ] 应用名称：企业安全聊天
  - [ ] 已添加授权网域（localhost + 生产域名）
  - [ ] 已选择必需作用域
- [ ] OAuth 客户端凭据已创建
  - [ ] 应用类型：Web 应用
  - [ ] JavaScript 来源已配置
  - [ ] 重定向 URI 已配置
- [ ] 客户端 ID 和密钥已保存

### 本地环境
- [ ] `.env.local` 文件已创建
- [ ] 凭据已填入环境变量
- [ ] `.gitignore` 已配置

### 安全检查
- [ ] 凭据文件未提交到 Git
- [ ] 生产环境使用 HTTPS
- [ ] 重定向 URI 使用 HTTPS（生产）

---

## 🔧 常见问题排查

### 问题 1：重定向 URI 不匹配

**错误信息**：
```
Error 400: redirect_uri_mismatch
```

**解决方案**：
1. 检查 Google Cloud Console 中的重定向 URI
2. 确保完全匹配：
   ```
   http://localhost:8081/api/v1/auth/oauth/google/callback
   ```
3. 注意：
   - 协议：http 或 https
   - 端口：8081
   - 路径：/api/v1/auth/oauth/google/callback
   - 无末尾斜杠

### 问题 2：无效客户端

**错误信息**：
```
Error 401: invalid_client
```

**解决方案**：
1. 检查 `GOOGLE_CLIENT_ID` 和 `GOOGLE_CLIENT_SECRET`
2. 确认没有多余的空格或换行
3. 验证密钥是否被撤销

### 问题 3：访问被拒绝

**错误信息**：
```
Error 403: access_denied
```

**解决方案**：
- **内部模式**：确认用户在 Google Workspace 组织内
- **外部模式**：确认用户在测试用户列表中（未发布时）

### 问题 4：作用域错误

**错误信息**：
```
Error 400: invalid_scope
```

**解决方案**：
1. 检查 OAuth 同意屏幕中的作用域配置
2. 确保添加了：
   - userinfo.email
   - userinfo.profile
   - openid

---

## 📝 配置信息记录表

请将您的配置信息记录在安全的地方：

```
项目信息
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
项目 ID：sec-chat-oauth-xxxxx
项目名称：sec-chat-oauth
组织：your-organization

OAuth 同意屏幕
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
应用名称：企业安全聊天
用户类型：内部/外部
授权网域：localhost, yourcompany.com

OAuth 客户端凭据
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
客户端 ID：[复制完整 ID]
客户端密钥：[复制完整密钥]
创建日期：2026-03-17

重定向 URI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
开发：http://localhost:8081/api/v1/auth/oauth/google/callback
生产：https://chat.yourcompany.com/api/v1/auth/oauth/google/callback

环境变量
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GOOGLE_CLIENT_ID=[客户端 ID]
GOOGLE_CLIENT_SECRET=[客户端密钥]
GOOGLE_REDIRECT_URL=[重定向 URI]
```

---

## 🎉 配置完成

完成以上步骤后，您已经：

1. ✅ 创建了 Google Cloud 项目
2. ✅ 配置了 OAuth 同意屏幕
3. ✅ 创建了 OAuth 2.0 客户端凭据
4. ✅ 配置了重定向 URI
5. ✅ 保存了凭据信息
6. ✅ 配置了本地环境变量

**下一步**：运行服务并测试 OAuth 登录流程！

---

## 📚 相关文档

- [Google OAuth 2.0 文档](https://developers.google.com/identity/protocols/oauth2)
- [OAuth 2.0 Playground](https://developers.google.com/oauthplayground/)
- [Google Cloud Console 帮助](https://support.google.com/cloud/)

---

**文档版本**: 1.0  
**创建日期**: 2026-03-17  
**适用项目**: 企业安全聊天应用
