const os = require('os');

module.exports = {
  name: 'dsh-ipad-memory-guard',
  description: 'Monitors device RAM dynamically and triggers global.gc() on high memory pressure',
  
  /**
   * 动态计算当前设备安全内存上限 (MB)：
   * 根据 os.totalmem() 动态判断：
   * - 4GB 及以下设备：512MB
   * - 6GB 设备 (如 iPhone 14 Pro Max A16 6GB)：800MB
   * - 8GB 及以上设备 (如 M2 iPad Pro 8GB/16GB)：1200MB
   */
  getDynamicLimitMB() {
    const totalBytes = os.totalmem ? os.totalmem() : 8 * 1024 * 1024 * 1024;
    const totalMB = Math.round(totalBytes / 1024 / 1024);
    if (totalMB <= 4096) {
      return 512;
    } else if (totalMB <= 6144) {
      return 800;
    } else {
      return 1200;
    }
  },

  checkMemory() {
    const mem = process.memoryUsage();
    const totalBytes = os.totalmem ? os.totalmem() : 8 * 1024 * 1024 * 1024;
    const totalRAMMB = Math.round(totalBytes / 1024 / 1024);
    const limitMB = this.getDynamicLimitMB();
    const rssMB = Math.round(mem.rss / 1024 / 1024);
    const heapUsedMB = Math.round(mem.heapUsed / 1024 / 1024);
    const heapTotalMB = Math.round(mem.heapTotal / 1024 / 1024);

    // 内存预警检测：当 RSS 超过安全上限的 80% 时自动预警并触发 GC
    const isWarning = rssMB > Math.round(limitMB * 0.8);
    if (isWarning) {
      this.triggerGC();
    }

    return {
      rssMB,
      heapUsedMB,
      heapTotalMB,
      totalRAMMB,
      limitMB,
      isWarning
    };
  },

  triggerGC() {
    if (typeof global.gc === 'function') {
      global.gc();
      return true;
    }
    return false;
  }
};