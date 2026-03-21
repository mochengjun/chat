/**
 * 性能测试脚本
 * 测试 Web 客户端的性能优化效果
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// 颜色输出
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// 执行命令
function runCommand(command, cwd = process.cwd()) {
  try {
    return execSync(command, { cwd, encoding: 'utf-8', stdio: 'pipe' });
  } catch (error) {
    return error.stdout || error.stderr || error.message;
  }
}

// 分析包体积
function analyzeBundleSize() {
  log('\n📦 分析 Web 客户端包体积...', 'cyan');
  
  const webClientPath = path.join(__dirname, '..', 'web-client');
  
  // 执行构建
  log('  → 执行生产环境构建...', 'yellow');
  const buildOutput = runCommand('npm run build', webClientPath);
  
  // 检查 dist 目录
  const distPath = path.join(webClientPath, 'dist', 'assets');
  
  if (!fs.existsSync(distPath)) {
    log('  ✗ 构建失败或 dist 目录不存在', 'red');
    return null;
  }
  
  // 分析文件大小
  const files = fs.readdirSync(distPath);
  const stats = {
    js: { count: 0, totalSize: 0, files: [] },
    css: { count: 0, totalSize: 0, files: [] },
    other: { count: 0, totalSize: 0, files: [] },
  };
  
  files.forEach(file => {
    const filePath = path.join(distPath, file);
    const stat = fs.statSync(filePath);
    const sizeKB = (stat.size / 1024).toFixed(2);
    
    if (file.endsWith('.js')) {
      stats.js.count++;
      stats.js.totalSize += stat.size;
      stats.js.files.push({ name: file, size: sizeKB });
    } else if (file.endsWith('.css')) {
      stats.css.count++;
      stats.css.totalSize += stat.size;
      stats.css.files.push({ name: file, size: sizeKB });
    } else {
      stats.other.count++;
      stats.other.totalSize += stat.size;
    }
  });
  
  // 打印结果
  log('\n  📊 包体积分析结果:', 'bright');
  log(`  ├─ JavaScript 文件: ${stats.js.count} 个, 总大小: ${(stats.js.totalSize / 1024).toFixed(2)} KB`, 'green');
  log(`  ├─ CSS 文件: ${stats.css.count} 个, 总大小: ${(stats.css.totalSize / 1024).toFixed(2)} KB`, 'green');
  log(`  └─ 其他文件: ${stats.other.count} 个, 总大小: ${(stats.other.totalSize / 1024).toFixed(2)} KB`, 'green');
  
  // 显示最大的 JS 文件
  const topJsFiles = stats.js.files
    .sort((a, b) => parseFloat(b.size) - parseFloat(a.size))
    .slice(0, 5);
  
  log('\n  📈 最大的 JS 文件 (Top 5):', 'cyan');
  topJsFiles.forEach((file, index) => {
    log(`    ${index + 1}. ${file.name}: ${file.size} KB`, 'reset');
  });
  
  return stats;
}

// 测试首屏加载时间
async function testPageLoadTime() {
  log('\n⏱️  测试首屏加载时间...', 'cyan');
  
  // 这里可以使用 Puppeteer 或 Lighthouse 进行自动化测试
  // 为了简化，我们只提供手动测试说明
  
  log('  ℹ️  首屏加载时间需要使用浏览器开发者工具测量', 'yellow');
  log('  建议测试步骤:', 'reset');
  log('    1. 启动开发服务器: cd web-client && npm run dev', 'reset');
  log('    2. 打开 Chrome DevTools > Performance 面板', 'reset');
  log('    3. 刷新页面并记录性能指标', 'reset');
  log('    4. 关注以下指标:', 'reset');
  log('       - FCP (First Contentful Paint): < 1.8s', 'reset');
  log('       - LCP (Largest Contentful Paint): < 2.5s', 'reset');
  log('       - TTI (Time to Interactive): < 3.8s', 'reset');
  log('       - CLS (Cumulative Layout Shift): < 0.1', 'reset');
  
  return {
    note: '首屏加载时间需要使用浏览器开发者工具测量',
  };
}

// 测试代码分割效果
function testCodeSplitting() {
  log('\n✂️  测试代码分割效果...', 'cyan');
  
  const webClientPath = path.join(__dirname, '..', 'web-client');
  const distPath = path.join(webClientPath, 'dist', 'assets');
  
  if (!fs.existsSync(distPath)) {
    log('  ✗ 请先运行构建: npm run build', 'red');
    return null;
  }
  
  const jsFiles = fs.readdirSync(distPath).filter(f => f.endsWith('.js'));
  
  // 分析 chunk 文件
  const vendorChunks = jsFiles.filter(f => f.includes('vendor'));
  const pageChunks = jsFiles.filter(f => !f.includes('vendor') && f.includes('-'));
  
  log('\n  📊 代码分割结果:', 'bright');
  log(`  ├─ Vendor chunks: ${vendorChunks.length} 个`, 'green');
  vendorChunks.forEach(f => {
    const size = (fs.statSync(path.join(distPath, f)).size / 1024).toFixed(2);
    log(`  │  └─ ${f}: ${size} KB`, 'reset');
  });
  
  log(`  └─ Page chunks: ${pageChunks.length} 个`, 'green');
  
  return {
    vendorChunks: vendorChunks.length,
    pageChunks: pageChunks.length,
  };
}

// 测试缓存效果
function testCaching() {
  log('\n💾 测试缓存效果...', 'cyan');
  
  log('  ℹ️  缓存效果需要在应用运行时测试', 'yellow');
  log('  测试步骤:', 'reset');
  log('    1. 打开浏览器开发者工具 > Network 面板', 'reset');
  log('    2. 刷新页面，观察请求是否命中缓存', 'reset');
  log('    3. 查看 localStorage 中的 request_cache 项', 'reset');
  log('    4. 检查控制台日志 [API] Cache hit: ...', 'reset');
  
  return {
    note: '缓存效果需要在应用运行时测试',
  };
}

// 生成性能测试报告
function generateReport(results) {
  log('\n📄 生成性能测试报告...', 'cyan');
  
  const reportPath = path.join(__dirname, '..', 'test-results', 'performance-report.md');
  const reportDir = path.dirname(reportPath);
  
  if (!fs.existsSync(reportDir)) {
    fs.mkdirSync(reportDir, { recursive: true });
  }
  
  const timestamp = new Date().toISOString();
  
  const report = `# 性能测试报告

生成时间: ${timestamp}

## 1. 包体积分析

${results.bundleSize ? `
- **JavaScript 文件**: ${results.bundleSize.js.count} 个，总大小 ${(results.bundleSize.js.totalSize / 1024).toFixed(2)} KB
- **CSS 文件**: ${results.bundleSize.css.count} 个，总大小 ${(results.bundleSize.css.totalSize / 1024).toFixed(2)} KB
- **其他文件**: ${results.bundleSize.other.count} 个，总大小 ${(results.bundleSize.other.totalSize / 1024).toFixed(2)} KB
` : '- 构建失败或数据不可用'}

## 2. 代码分割效果

${results.codeSplitting ? `
- **Vendor chunks**: ${results.codeSplitting.vendorChunks} 个
- **Page chunks**: ${results.codeSplitting.pageChunks} 个
` : '- 数据不可用'}

## 3. 优化建议

### 已实施的优化

1. **代码分割**
   - React 生态库独立 chunk (react-vendor)
   - UI 组件库独立 chunk (antd-vendor)
   - 状态管理独立 chunk (state-vendor)
   - 国际化独立 chunk (i18n-vendor)
   - 工具库独立 chunk (utils-vendor)

2. **懒加载**
   - 所有页面组件使用 React.lazy 懒加载
   - 添加 Suspense 加载指示器

3. **性能优化组件**
   - MessageItem 使用 React.memo 优化
   - 自定义比较函数避免不必要渲染

4. **网络优化**
   - 请求缓存管理器 (内存 + localStorage)
   - 并发控制器 (限制同时请求数)
   - Terser 生产环境压缩

5. **性能监控**
   - Web Vitals 指标收集
   - 性能数据上报

### 进一步优化建议

1. **图片优化**
   - 使用 WebP 格式
   - 实施图片懒加载
   - 使用 CDN 加速

2. **字体优化**
   - 使用 font-display: swap
   - 预加载关键字体

3. **服务端优化**
   - 启用 HTTP/2
   - 启用 Gzip/Brotli 压缩
   - 配置浏览器缓存策略

## 4. 性能目标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| FCP  | < 1.8s | 首次内容绘制 |
| LCP  | < 2.5s | 最大内容绘制 |
| FID  | < 100ms | 首次输入延迟 |
| CLS  | < 0.1 | 累积布局偏移 |
| TTI  | < 3.8s | 可交互时间 |

---

*报告由性能测试脚本自动生成*
`;

  fs.writeFileSync(reportPath, report, 'utf-8');
  log(`  ✓ 报告已保存到: ${reportPath}`, 'green');
  
  return reportPath;
}

// 主函数
async function main() {
  log('\n' + '='.repeat(60), 'bright');
  log('🚀 性能测试开始', 'bright');
  log('='.repeat(60), 'bright');
  
  const results = {
    bundleSize: null,
    pageLoad: null,
    codeSplitting: null,
    caching: null,
  };
  
  // 执行测试
  results.bundleSize = analyzeBundleSize();
  results.pageLoad = await testPageLoadTime();
  results.codeSplitting = testCodeSplitting();
  results.caching = testCaching();
  
  // 生成报告
  const reportPath = generateReport(results);
  
  log('\n' + '='.repeat(60), 'bright');
  log('✅ 性能测试完成', 'green');
  log('='.repeat(60), 'bright');
  
  log(`\n📄 查看详细报告: ${reportPath}`, 'cyan');
}

// 运行测试
main().catch(console.error);
