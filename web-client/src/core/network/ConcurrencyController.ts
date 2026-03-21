/**
 * 请求并发控制器
 * 限制同时进行的请求数量，避免浏览器连接数限制
 */

interface QueueItem {
  execute: () => Promise<any>;
  resolve: (value: any) => void;
  reject: (error: any) => void;
}

class ConcurrencyController {
  private queue: QueueItem[] = [];
  private activeCount = 0;
  private maxConcurrency: number;

  constructor(maxConcurrency: number = 6) {
    // 浏览器 HTTP/1.1 同域名并发限制通常是 6
    this.maxConcurrency = maxConcurrency;
  }

  // 执行下一个队列任务
  private next(): void {
    if (this.queue.length === 0 || this.activeCount >= this.maxConcurrency) {
      return;
    }

    this.activeCount++;
    const item = this.queue.shift()!;

    item.execute()
      .then((value) => {
        item.resolve(value);
      })
      .catch((error) => {
        item.reject(error);
      })
      .finally(() => {
        this.activeCount--;
        this.next();
      });
  }

  // 包装请求函数，加入并发控制
  wrap<T>(execute: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push({ execute, resolve, reject });
      this.next();
    });
  }

  // 获取当前状态
  getStatus() {
    return {
      queueLength: this.queue.length,
      activeCount: this.activeCount,
      maxConcurrency: this.maxConcurrency,
    };
  }

  // 更新最大并发数
  setMaxConcurrency(max: number): void {
    this.maxConcurrency = max;
    // 尝试执行队列中的任务
    this.next();
  }

  // 清空队列
  clear(): void {
    this.queue.forEach((item) => {
      item.reject(new Error('Request cancelled'));
    });
    this.queue = [];
  }
}

// 单例导出
export const concurrencyController = new ConcurrencyController(6);
