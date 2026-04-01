import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@core': path.resolve(__dirname, './src/core'),
      '@domain': path.resolve(__dirname, './src/domain'),
      '@data': path.resolve(__dirname, './src/data'),
      '@presentation': path.resolve(__dirname, './src/presentation'),
      '@shared': path.resolve(__dirname, './src/shared'),
    },
  },
  server: {
    port: 3000,
    host: true, // 允许外网访问
    proxy: {
      '/api': {
        // 使用实际服务器IP地址
        // 注意：如果服务器IP变化，需要更新此配置
        target: 'http://8.130.55.126:8081',
        changeOrigin: true,
        ws: true, // 同时代理 WebSocket（/api/v1/ws）
      },
    },
  },
  build: {
    // 代码分割优化
    rollupOptions: {
      output: {
        // 手动分割代码块
        manualChunks: {
          // React 生态核心库
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          // UI 组件库
          'antd-vendor': ['antd', '@ant-design/icons'],
          // 状态管理和数据获取
          'state-vendor': ['zustand', '@tanstack/react-query'],
          // 国际化
          'i18n-vendor': ['i18next', 'react-i18next', 'i18next-browser-languagedetector'],
          // 工具库
          'utils-vendor': ['axios', 'dayjs', 'dompurify'],
        },
        // 优化文件命名
        chunkFileNames: (chunkInfo) => {
          const facadeModuleId = chunkInfo.facadeModuleId ? chunkInfo.facadeModuleId.split('/').pop() : 'chunk';
          return `assets/${chunkInfo.name || facadeModuleId}-[hash].js`;
        },
      },
    },
    // 压缩选项
    minify: 'terser',
    terserOptions: {
      compress: {
        // 生产环境移除 console
        drop_console: true,
        drop_debugger: true,
        // 优化压缩
        pure_funcs: ['console.log', 'console.info', 'console.debug'],
      },
      format: {
        // 移除注释
        comments: false,
      },
    },
    // CSS 代码分割
    cssCodeSplit: true,
    // 启用 Source Map（生产环境可选关闭以减小体积）
    sourcemap: false,
    // 块大小警告阈值
    chunkSizeWarningLimit: 500,
    // 启用 gzip 压缩大小报告
    reportCompressedSize: true,
  },
  // 优化依赖预构建
  optimizeDeps: {
    include: [
      'react',
      'react-dom',
      'react-router-dom',
      'antd',
      '@ant-design/icons',
      'zustand',
      '@tanstack/react-query',
      'axios',
      'dayjs',
      'i18next',
      'react-i18next',
    ],
    exclude: ['@vitejs/plugin-react'],
  },
})
