/**
 * dsh-ipad-prompt-optimizer
 * Pad Harness 纯本地结构化提示词调优插件
 * 零云端消耗，规则化精准优化
 */
module.exports = {
  name: 'dsh-ipad-prompt-optimizer',
  description: 'Pad Harness 纯本地结构化提示词调优引擎',
  async optimizePrompt({ prompt, targetTask = 'general', language = 'zh-CN' }) {
    if (!prompt || typeof prompt !== 'string') return { optimizedPrompt: prompt };
    
    // 结构化增强骨架
    const prefix = [
      '【任务目标与上下文约束】',
      prompt.trim(),
      '',
      '【执行标准】',
      '1. 严谨、专业、结构清晰；',
      '2. 代码输出优先使用完整、自包含且带类型约束的实现；',
      '3. 消除歧义，优先提供直接落地执行的方案。'
    ].join('\n');

    return {
      originalPrompt: prompt,
      optimizedPrompt: prefix,
      targetTask,
      language
    };
  }
};