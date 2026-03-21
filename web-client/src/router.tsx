import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Spin } from 'antd';
import { MainLayout } from '@presentation/components/common/MainLayout';
import { useAuthStore } from '@presentation/stores/authStore';
import { ROUTES } from '@shared/constants/config';

// 懒加载页面组件
const LoginPage = lazy(() => import('@presentation/pages/auth/LoginPage').then(m => ({ default: m.LoginPage })));
const RegisterPage = lazy(() => import('@presentation/pages/auth/RegisterPage').then(m => ({ default: m.RegisterPage })));
const ChatRoomListPage = lazy(() => import('@presentation/pages/chat/ChatRoomListPage').then(m => ({ default: m.ChatRoomListPage })));
const ChatRoomPage = lazy(() => import('@presentation/pages/chat/ChatRoomPage').then(m => ({ default: m.ChatRoomPage })));
const RoomMembersPage = lazy(() => import('@presentation/pages/chat/RoomMembersPage').then(m => ({ default: m.RoomMembersPage })));
const BrowseGroupsPage = lazy(() => import('@presentation/pages/chat/BrowseGroupsPage').then(m => ({ default: m.BrowseGroupsPage })));

// 全屏加载指示器
function PageLoader() {
  return (
    <div style={{ 
      display: 'flex', 
      justifyContent: 'center', 
      alignItems: 'center', 
      height: '100vh' 
    }}>
      <Spin size="large" />
    </div>
  );
}

// 受保护的路由组件
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isInitialized } = useAuthStore();
  
  // 等待 initializeAuth 完成后再做路由判断，防止持久化状态闪烁
  if (!isInitialized) {
    return null;
  }
  
  if (!isAuthenticated) {
    return <Navigate to={ROUTES.LOGIN} replace />;
  }
  
  return <>{children}</>;
}

// 公开路由组件（已登录时跳转到聊天页）
function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isInitialized } = useAuthStore();
  
  if (!isInitialized) {
    return null;
  }
  
  if (isAuthenticated) {
    return <Navigate to={ROUTES.CHAT} replace />;
  }
  
  return <>{children}</>;
}

export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        {/* 公开路由 */}
        <Route
          path={ROUTES.LOGIN}
          element={
            <PublicRoute>
              <Suspense fallback={<PageLoader />}>
                <LoginPage />
              </Suspense>
            </PublicRoute>
          }
        />
        <Route
          path={ROUTES.REGISTER}
          element={
            <PublicRoute>
              <Suspense fallback={<PageLoader />}>
                <RegisterPage />
              </Suspense>
            </PublicRoute>
          }
        />

        {/* 受保护的路由 */}
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <MainLayout />
            </ProtectedRoute>
          }
        >
          <Route index element={<Navigate to={ROUTES.CHAT} replace />} />
          <Route 
            path="chat" 
            element={
              <Suspense fallback={<PageLoader />}>
                <ChatRoomListPage />
              </Suspense>
            } 
          />
          <Route 
            path="chat/browse" 
            element={
              <Suspense fallback={<PageLoader />}>
                <BrowseGroupsPage />
              </Suspense>
            } 
          />
          <Route 
            path="chat/:roomId" 
            element={
              <Suspense fallback={<PageLoader />}>
                <ChatRoomPage />
              </Suspense>
            } 
          />
          <Route 
            path="chat/:roomId/members" 
            element={
              <Suspense fallback={<PageLoader />}>
                <RoomMembersPage />
              </Suspense>
            } 
          />
          <Route path="settings" element={<div style={{ padding: 24 }}>设置页面（待实现）</div>} />
        </Route>

        {/* 404 重定向 */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
