/**
 * Web Vitals 性能监控工具
 * 收集核心性能指标并上报
 */

interface PerformanceMetric {
  name: string;
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  timestamp: number;
}

interface PerformanceReport {
  metrics: PerformanceMetric[];
  url: string;
  userAgent: string;
  timestamp: number;
}

// 性能指标阈值（根据 Google Web Vitals 标准）
const THRESHOLDS = {
  // Largest Contentful Paint（最大内容绘制）
  LCP: { good: 2500, poor: 4000 },
  // First Input Delay（首次输入延迟）
  FID: { good: 100, poor: 300 },
  // Cumulative Layout Shift（累积布局偏移）
  CLS: { good: 0.1, poor: 0.25 },
  // Time to First Byte（首字节时间）
  TTFB: { good: 800, poor: 1800 },
  // First Contentful Paint（首次内容绘制）
  FCP: { good: 1800, poor: 3000 },
};

// 性能指标存储
const metrics: Map<string, PerformanceMetric> = new Map();

// 获取指标评级
function getRating(name: string, value: number): 'good' | 'needs-improvement' | 'poor' {
  const threshold = THRESHOLDS[name as keyof typeof THRESHOLDS];
  if (!threshold) return 'good';
  
  if (value <= threshold.good) return 'good';
  if (value <= threshold.poor) return 'needs-improvement';
  return 'poor';
}

// 观察 Performance Entries
function observePerformanceEntries() {
  if (typeof window === 'undefined' || !('PerformanceObserver' in window)) {
    return;
  }

  // 观察 LCP
  try {
    const lcpObserver = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const lastEntry = entries[entries.length - 1];
      
      const metric: PerformanceMetric = {
        name: 'LCP',
        value: lastEntry.startTime,
        rating: getRating('LCP', lastEntry.startTime),
        timestamp: Date.now(),
      };
      
      metrics.set('LCP', metric);
      console.log('[Performance] LCP:', metric);
    });
    
    lcpObserver.observe({ type: 'largest-contentful-paint', buffered: true });
  } catch (e) {
    console.warn('[Performance] LCP observer not supported');
  }

  // 观察 FID
  try {
    const fidObserver = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry) => {
        if (entry.entryType === 'first-input') {
          const metric: PerformanceMetric = {
            name: 'FID',
            value: (entry as PerformanceEventTiming).processingStart - entry.startTime,
            rating: getRating('FID', (entry as PerformanceEventTiming).processingStart - entry.startTime),
            timestamp: Date.now(),
          };
          
          metrics.set('FID', metric);
          console.log('[Performance] FID:', metric);
        }
      });
    });
    
    fidObserver.observe({ type: 'first-input', buffered: true });
  } catch (e) {
    console.warn('[Performance] FID observer not supported');
  }

  // 观察 CLS
  try {
    let clsValue = 0;
    const clsObserver = new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (!(entry as any).hadRecentInput) {
          clsValue += (entry as any).value;
        }
      }
      
      const metric: PerformanceMetric = {
        name: 'CLS',
        value: clsValue,
        rating: getRating('CLS', clsValue),
        timestamp: Date.now(),
      };
      
      metrics.set('CLS', metric);
    });
    
    clsObserver.observe({ type: 'layout-shift', buffered: true });
  } catch (e) {
    console.warn('[Performance] CLS observer not supported');
  }
}

// 获取导航计时指标
function getNavigationTiming() {
  if (typeof window === 'undefined' || !window.performance?.timing) {
    return;
  }

  const timing = window.performance.timing;
  const navigationStart = timing.navigationStart;

  // TTFB
  const ttfb = timing.responseStart - navigationStart;
  metrics.set('TTFB', {
    name: 'TTFB',
    value: ttfb,
    rating: getRating('TTFB', ttfb),
    timestamp: Date.now(),
  });

  // FCP
  const fcp = timing.domContentLoadedEventEnd - navigationStart;
  metrics.set('FCP', {
    name: 'FCP',
    value: fcp,
    rating: getRating('FCP', fcp),
    timestamp: Date.now(),
  });

  console.log('[Performance] Navigation Timing:', { TTFB: ttfb, FCP: fcp });
}

// 获取资源加载性能
function getResourceTiming() {
  if (typeof window === 'undefined' || !window.performance?.getEntriesByType) {
    return [];
  }

  const resources = window.performance.getEntriesByType('resource') as PerformanceResourceTiming[];
  
  return resources.map((resource) => ({
    name: resource.name,
    duration: resource.duration,
    size: resource.transferSize,
    type: resource.initiatorType,
  }));
}

// 收集所有性能指标
function collectMetrics(): PerformanceReport {
  getNavigationTiming();
  
  return {
    metrics: Array.from(metrics.values()),
    url: window.location.href,
    userAgent: navigator.userAgent,
    timestamp: Date.now(),
  };
}

// 上报性能数据（可对接后端 API）
async function reportMetrics(report: PerformanceReport) {
  try {
    // 开发环境只打印日志
    if (process.env.NODE_ENV === 'development') {
      console.log('[Performance] Metrics Report:', report);
      return;
    }

    // 生产环境可上报到后端
    // await fetch('/api/v1/analytics/performance', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify(report),
    // });
    
    console.log('[Performance] Metrics reported:', report);
  } catch (error) {
    console.error('[Performance] Failed to report metrics:', error);
  }
}

// 初始化性能监控
export function initPerformanceMonitoring() {
  if (typeof window === 'undefined') {
    return;
  }

  // 页面加载完成后收集指标
  window.addEventListener('load', () => {
    // 延迟收集，确保所有指标都已测量
    setTimeout(() => {
      observePerformanceEntries();
      
      const report = collectMetrics();
      reportMetrics(report);
    }, 1000);
  });

  // 页面卸载时再次上报
  window.addEventListener('beforeunload', () => {
    const report = collectMetrics();
    // 使用 sendBeacon 确保数据发送
    if (navigator.sendBeacon && process.env.NODE_ENV === 'production') {
      const blob = new Blob([JSON.stringify(report)], { type: 'application/json' });
      navigator.sendBeacon('/api/v1/analytics/performance', blob);
    }
  });
}

// 导出工具函数
export { collectMetrics, getResourceTiming, reportMetrics };
