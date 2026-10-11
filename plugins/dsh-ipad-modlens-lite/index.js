/**
 * dsh-ipad-modlens-lite
 * 对标 @liustack/modlens
 * iPadOS 原生相册与截图多模态轻量转接器，流式切片送云端
 */
module.exports = {
  name: 'dsh-ipad-modlens-lite',
  description: 'Pad Harness 轻量多模态图像感知解析器',
  async inspectImage({ imageBase64, prompt = '请详细分析图中的代码、终端输出或文本内容' }) {
    if (!imageBase64) return { error: 'imageBase64 is required' };
    
    // 构造对标云端 vision 模型的结构化多模态 Prompt
    return {
      status: 'prepared',
      prompt,
      hasPayload: Boolean(imageBase64),
      estimatedSizeKB: Math.round(imageBase64.length * 0.75 / 1024)
    };
  }
};