import { Form, Input, Button, Card, Typography, message } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { useNavigate, Link } from 'react-router-dom';
import { useAuthStore } from '@presentation/stores/authStore';
import { ROUTES } from '@shared/constants/config';
import type { LoginRequest } from '@shared/types/api.types';
import { OAuthButtons } from './OAuthButtons';

const { Title, Text } = Typography;

export function LoginPage() {
  const [form] = Form.useForm<LoginRequest>();
  const { login, isLoading, error, clearError } = useAuthStore();
  const navigate = useNavigate();

  const handleLogin = async (values: LoginRequest) => {
    clearError();
    try {
      await login(values);
      message.success('登录成功');
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
          maxWidth: 420,
          borderRadius: 12,
          boxShadow: '0 10px 40px rgba(0,0,0,0.2)',
        }}
        styles={{ body: { padding: '40px 32px' } }}
      >
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <Title level={2} style={{ margin: 0, color: '#1a1a2e' }}>
            安全聊天
          </Title>
          <Text type="secondary">企业级安全通讯平台</Text>
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
          onFinish={handleLogin}
          layout="vertical"
          size="large"
        >
          <Form.Item
            name="username"
            rules={[{ required: true, message: '请输入用户名' }]}
          >
            <Input
              prefix={<UserOutlined />}
              placeholder="用户名"
              autoComplete="username"
            />
          </Form.Item>

          <Form.Item
            name="password"
            rules={[{ required: true, message: '请输入密码' }]}
          >
            <Input.Password
              prefix={<LockOutlined />}
              placeholder="密码"
              autoComplete="current-password"
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
              登录
            </Button>
          </Form.Item>
        </Form>

        {/* OAuth 登录按钮 */}
        <OAuthButtons 
          onSuccess={() => {
            message.success('登录成功');
            navigate(ROUTES.CHAT);
          }}
          onError={(err) => {
            message.error(err);
          }}
        />

        <div style={{ textAlign: 'center', marginTop: 16 }}>
          <Text type="secondary">
            没有账号？{' '}
            <Link to={ROUTES.REGISTER} style={{ color: '#667eea' }}>
              立即注册
            </Link>
          </Text>
        </div>
      </Card>
    </div>
  );
}
