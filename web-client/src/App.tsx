import { useEffect } from 'react';
import { ConfigProvider, App as AntdApp } from 'antd';
import zhCN from 'antd/locale/zh_CN';
import enUS from 'antd/locale/en_US';
import { AppRouter } from './router';
import { useAuthStore } from '@presentation/stores/authStore';
import { useTranslation } from 'react-i18next';
import dayjs from 'dayjs';
import 'dayjs/locale/zh-cn';

function App() {
  const { initializeAuth } = useAuthStore();
  const { i18n } = useTranslation();

  useEffect(() => {
    initializeAuth();
  }, [initializeAuth]);

  // 根据语言设置 dayjs locale
  useEffect(() => {
    dayjs.locale(i18n.language === 'zh-CN' ? 'zh-cn' : 'en');
  }, [i18n.language]);

  // 根据当前语言选择 Ant Design locale
  const antdLocale = i18n.language === 'zh-CN' ? zhCN : enUS;

  return (
    <ConfigProvider
      locale={antdLocale}
      theme={{
        token: {
          colorPrimary: '#667eea',
          borderRadius: 8,
        },
      }}
    >
      <AntdApp>
        <AppRouter />
      </AntdApp>
    </ConfigProvider>
  );
}

export default App;
