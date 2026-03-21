import { Button, Divider, message } from 'antd';
import { GoogleOutlined, WechatOutlined } from '@ant-design/icons';
import { useAuthStore } from '@presentation/stores/authStore';

interface OAuthButtonsProps {
  onSuccess?: () => void;
  onError?: (error: string) => void;
}

export function OAuthButtons({ onSuccess, onError }: OAuthButtonsProps) {
  const { loginWithGoogle, oauthLoading, error } = useAuthStore();

  const handleGoogleLogin = async () => {
    try {
      await loginWithGoogle();
      message.success('Google 登录成功');
      onSuccess?.();
    } catch {
      onError?.(error || 'Google 登录失败');
    }
  };

  return (
    <>
      <Divider plain style={{ margin: '16px 0' }}>
        <span style={{ color: '#999', fontSize: 12 }}>或使用第三方登录</span>
      </Divider>

      <div style={{ display: 'flex', gap: 12, flexDirection: 'column' }}>
        {/* Google 登录按钮 */}
        <Button
          icon={<GoogleOutlined />}
          size="large"
          block
          loading={oauthLoading.google}
          onClick={handleGoogleLogin}
          style={{
            height: 44,
            borderColor: '#4285f4',
            color: '#4285f4',
          }}
        >
          使用 Google 账号登录
        </Button>

        {/* 微信登录按钮 - 暂时禁用 */}
        <Button
          icon={<WechatOutlined />}
          size="large"
          block
          disabled
          style={{
            height: 44,
            borderColor: '#07c160',
            color: '#07c160',
          }}
        >
          使用微信账号登录（即将支持）
        </Button>
      </div>
    </>
  );
}
