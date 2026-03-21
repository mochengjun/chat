// Commitlint 配置文件
// 遵循约定式提交规范 (Conventional Commits 1.0.0)
// 文档: https://commitlint.js.org/

module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // 类型定义
    'type-enum': [
      2,
      'always',
      [
        'feat',     // 新功能
        'fix',      // Bug 修复
        'docs',     // 文档更新
        'style',    // 代码格式
        'refactor', // 重构
        'test',     // 测试
        'chore',    // 构建/工具
        'perf',     // 性能优化
        'ci',       // CI 配置
        'build',    // 构建系统
        'revert',   // 回滚
      ],
    ],
    // 作用域定义
    'scope-enum': [
      1,
      'always',
      [
        // 模块
        'flutter-app',
        'web-client',
        'auth-service',
        'push-service',
        'media-proxy',
        'admin-service',
        // 功能域
        'auth',
        'chat',
        'webrtc',
        'push',
        'media',
        'api',
        'ui',
        'db',
        'cache',
        // 基础设施
        'docker',
        'k8s',
        'ci',
        'deps',
        // 其他
        'docs',
        'security',
      ],
    ],
    // 主题格式
    'subject-case': [2, 'always', 'lower-case'],
    'subject-max-length': [2, 'always', 72],
    'subject-min-length': [2, 'always', 5],
    'subject-full-stop': [2, 'never', '.'],
    
    // 主题不能为空
    'subject-empty': [2, 'never'],
    'type-empty': [2, 'never'],
    
    // 主题格式: <type>(<scope>): <subject>
    'type-case': [2, 'always', 'lower-case'],
    
    // 正文每行最大长度
    'body-max-line-length': [2, 'always', 100],
    
    // 页脚格式
    'footer-leading-blank': [2, 'always'],
    
    // 标题行最大长度
    'header-max-length': [2, 'always', 100],
  },
  // 提示信息配置
  prompt: {
    messages: {
      type: '选择提交类型:',
      scope: '选择影响范围 (可选):',
      customScope: '输入自定义范围:',
      subject: '输入简短描述 (5-72字符):\n',
      body: '输入详细描述 (可选，按回车跳过):\n',
      breaking: '是否有破坏性变更?',
      footerPrefixsSelect: '选择关联的 Issue 类型:',
      customFooterPrefixs: '输入自定义 Issue 前缀:',
      footer: '关联的 Issue (可选):\n',
      confirmCommit: '确认提交?',
    },
    types: [
      { value: 'feat', name: 'feat:     ✨  新功能', emoji: ':sparkles:' },
      { value: 'fix', name: 'fix:      🐛  Bug 修复', emoji: ':bug:' },
      { value: 'docs', name: 'docs:     📚  文档更新', emoji: ':book:' },
      { value: 'style', name: 'style:    💄  代码格式', emoji: ':lipstick:' },
      { value: 'refactor', name: 'refactor: ♻️  代码重构', emoji: ':recycle:' },
      { value: 'test', name: 'test:     ✅  测试相关', emoji: ':white_check_mark:' },
      { value: 'chore', name: 'chore:    🔧  构建/工具', emoji: ':wrench:' },
      { value: 'perf', name: 'perf:     ⚡  性能优化', emoji: ':zap:' },
      { value: 'ci', name: 'ci:       🎡  CI 配置', emoji: ':ferris_wheel:' },
      { value: 'build', name: 'build:    📦  构建系统', emoji: ':package:' },
      { value: 'revert', name: 'revert:   ⏪  回滚提交', emoji: ':rewind:' },
    ],
    scopes: [
      { value: 'flutter-app', name: 'flutter-app: Flutter 应用' },
      { value: 'web-client', name: 'web-client: Web 客户端' },
      { value: 'auth-service', name: 'auth-service: 认证服务' },
      { value: 'push-service', name: 'push-service: 推送服务' },
      { value: 'media-proxy', name: 'media-proxy: 媒体代理' },
      { value: 'admin-service', name: 'admin-service: 管理服务' },
      { value: 'docker', name: 'docker: Docker 配置' },
      { value: 'k8s', name: 'k8s: Kubernetes 配置' },
      { value: 'ci', name: 'ci: CI/CD 配置' },
      { value: 'deps', name: 'deps: 依赖管理' },
      { value: 'docs', name: 'docs: 文档' },
      { value: 'security', name: 'security: 安全相关' },
    ],
  },
};
