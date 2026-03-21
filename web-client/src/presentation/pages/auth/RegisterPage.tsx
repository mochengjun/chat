import { useState } from 'react';
import { Form, Input, Button, Card, Typography, message, Progress, Space } from 'antd';
import { UserOutlined, LockOutlined, MailOutlined, IdcardOutlined } from '@ant-design/icons';
import { useNavigate, Link } from 'react-router-dom';
import { useAuthStore } from '@presentation/stores/authStore';
import { ROUTES } from '@shared/constants/config';
import type { RegisterRequest } from '@shared/types/api.types';

const { Title, Text } = Typography;

// 密码强度检测
function getPasswordStrength(password: string): { score: number; label: string; color: string } {
  let score = 0;
  
  if (password.length >= 6) score += 1;
  if (password.length >= 8) score += 1;
  if (/[a-z]/.test(password)) score += 1;
  if (/[A-Z]/.test(password)) score += 1;
  if (/[0-9]/.test(password)) score += 1;
  if (/[^a-zA-Z0-9]/.test(password)) score += 1;
  
  if (score <= 2) return { score: 25, label: '弱', color: '#ff4d4f' };
  if (score <= 3) return { score: 50, label: '中', color: '#faad14' };
  if (score <= 4) return { score: 75, label: '强', color: '#52c41a' };
  return { score: 100, label: '非常强', color: '#1890ff' };
}

// 用户名验证规则
const usernameRules = [
  { required: true, message: '请输入用户名' },
  { min: 3, message: '用户名至少3个字符' },
  { max: 20, message: '用户名最多20个字符' },
  { 
    pattern: /^[a-zA-Z][a-zA-Z0-9_]*$/, 
    message: '用户名必须以字母开头，只能包含字母、数字和下划线' 
  },
];

// 邮箱验证规则
const emailRules = [
  { required: true, message: '请输入邮箱' },
  { type: 'email' as const, message: '请输入有效的邮箱地址' },
  { max: 100, message: '邮箱地址过长' },
];

// 密码验证规则
const passwordRules = [
  { required: true, message: '请输入密码' },
  { min: 6, message: '密码至少6个字符' },
  { max: 50, message: '密码最多50个字符' },
  {
    pattern: /^(?=.*[a-zA-Z])(?=.*\d).+$/,
    message: '密码必须包含字母和数字',
  },
];

interface RegisterFormValues extends RegisterRequest {
  confirmPassword: string;
}

export function RegisterPage() {
  const [form] = Form.useForm<RegisterFormValues>();
  const [password, setPassword] = useState('');
  const { register, isLoading, error, clearError } = useAuthStore();
  const navigate = useNavigate();

  const passwordStrength = getPasswordStrength(password);

  const handleRegister = async (values: RegisterFormValues) => {
    clearError();
    try {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { confirmPassword: _, ...registerData } = values;
      await register(registerData);
      message.success('注册成功，正在跳转...');
      navigate(ROUTES.CHAT);
    } catch {
      // 错误已在store中处理
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '20px',
    }}>
      <Card
        style={{
          width: '100%',
          maxWidth: 450,
          borderRadius: 12,
          boxShadow: '0 10px 40px rgba(0,0,0,0.2)',
        }}
        styles={{ body: { padding: '40px 32px' } }}
      >
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <Title level={2} style={{ margin: 0, color: '#1a1a2e' }}>
            创建账号
          </Title>
          <Text type="secondary">加入企业级安全通讯平台</Text>
        </div>

        {error && (
          <div style={{ 
            marginBottom: 16, 
            padding: '8px 12px', 
            background: '#fff2f0', 
            border: '1px solid #ffccc7',
            borderRadius: 6,
            color: '#ff4d4f',
          }}>
            {error}
          </div>
        )}

        <Form
          form={form}
          onFinish={handleRegister}
          layout="vertical"
          size="large"
          autoComplete="off"
        >
          <Form.Item
            name="username"
            rules={usernameRules}
            validateTrigger={['onBlur', 'onChange']}
          >
            <Input
              prefix={<UserOutlined />}
              placeholder="用户名（字母开头，3-20字符）"
              autoComplete="username"
            />
          </Form.Item>

          <Form.Item
            name="email"
            rules={emailRules}
            validateTrigger={['onBlur', 'onChange']}
          >
            <Input
              prefix={<MailOutlined />}
              placeholder="邮箱地址"
              autoComplete="email"
            />
          </Form.Item>

          <Form.Item
            name="display_name"
            rules={[{ max: 50, message: '显示名称最多50个字符' }]}
          >
            <Input
              prefix={<IdcardOutlined />}
              placeholder="显示名称（可选，用于聊天展示）"
            />
          </Form.Item>

          <Form.Item
            name="password"
            rules={passwordRules}
            validateTrigger={['onBlur', 'onChange']}
          >
            <Input.Password
              prefix={<LockOutlined />}
              placeholder="密码（至少6位，含字母和数字）"
              autoComplete="new-password"
              onChange={(e) => setPassword(e.target.value)}
            />
          </Form.Item>

          {password && (
            <div style={{ marginBottom: 16, marginTop: -8 }}>
              <Space style={{ width: '100%', justifyContent: 'space-between' }}>
                <Text type="secondary" style={{ fontSize: 12 }}>密码强度：</Text>
                <Text style={{ fontSize: 12, color: passwordStrength.color }}>
                  {passwordStrength.label}
                </Text>
              </Space>
              <Progress 
                percent={passwordStrength.score} 
                showInfo={false} 
                strokeColor={passwordStrength.color}
                size="small"
              />
            </div>
          )}

          <Form.Item
            name="confirmPassword"
            dependencies={['password']}
            rules={[
              { required: true, message: '请确认密码' },
              ({ getFieldValue }) => ({
                validator(_, value) {
                  if (!value || getFieldValue('password') === value) {
                    return Promise.resolve();
                  }
                  return Promise.reject(new Error('两次输入的密码不一致'));
                },
              }),
            ]}
            validateTrigger={['onBlur', 'onChange']}
          >
            <Input.Password
              prefix={<LockOutlined />}
              placeholder="确认密码"
              autoComplete="new-password"
            />
          </Form.Item>

          <Form.Item style={{ marginBottom: 16 }}>
            <Button
              type="primary"
              htmlType="submit"
              loading={isLoading}
              block
              style={{ height: 44 }}
            >
              注册
            </Button>
          </Form.Item>

          <div style={{ textAlign: 'center' }}>
            <Text type="secondary">
              已有账号？{' '}
              <Link to={ROUTES.LOGIN} style={{ color: '#667eea' }}>
                立即登录
              </Link>
            </Text>
          </div>
        </Form>
      </Card>
    </div>
  );
}
