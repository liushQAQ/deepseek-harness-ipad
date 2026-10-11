/**
 * dsh-ipad-cost-meter
 * Pad Harness 轻量化 Token 计费统计插件
 * 零后台常驻，磁盘 SQLite / JSON 存储统计
 */
module.exports = {
  name: 'dsh-ipad-cost-meter',
  description: '轻量化 Token 与 API 消耗计量插件',
  async recordUsage({ model = 'deepseek-chat', promptTokens = 0, completionTokens = 0 }) {
    // DeepSeek 官方定价计费规则 (元 / 百万 tokens)
    const RATES = {
      'deepseek-chat': { prompt: 1.0, completion: 2.0 },
      'deepseek-reasoner': { prompt: 2.0, completion: 8.0 }
    };
    const rate = RATES[model] || RATES['deepseek-chat'];
    const cost = ((promptTokens * rate.prompt) + (completionTokens * rate.completion)) / 1000000;
    return {
      model,
      promptTokens,
      completionTokens,
      totalTokens: promptTokens + completionTokens,
      estimatedCostRMB: Number(cost.toFixed(6))
    };
  }
};