/**
 * Pad Harness Standalone Server Entry
 * 独立运行在 iPad 本机的 DSH 服务端调度中枢
 * 架构核心：
 * 1. 监听 0.0.0.0:3080（iPad 本机闭环回环 + 开放局域网供外部客户端连接）
 * 2. 内存硬锁定 --max-old-space-size=1024，空闲主动 GC
 * 3. 动态调度自研 8 大轻量插件矩阵（真终端、内存守护、会话归档等）
 * 4. 内置完整 WebUI 交互工作台（直接返回响应式现代化控制台）
 * 5. 全程直接调用云端 DeepSeek 官方 API，不依赖任何外部电脑
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const https = require('https');

const PORT = parseInt(process.env.PORT || '3080', 10);
const HOST = process.env.HOST || '0.0.0.0';

// 8 大自研轻量插件动态注册表
const PLUGINS = {
  'dsh-ipad-posix-exec': require('../plugins/dsh-ipad-posix-exec/index.js'),
  'dsh-ipad-memory-guard': require('../plugins/dsh-ipad-memory-guard/index.js'),
  'dsh-ipad-storage-sync': require('../plugins/dsh-ipad-storage-sync/index.js'),
  'dsh-ipad-market': require('../plugins/dsh-ipad-market/index.js'),
  'dsh-ipad-cost-meter': require('../plugins/dsh-ipad-cost-meter/index.js'),
  'dsh-ipad-prompt-optimizer': require('../plugins/dsh-ipad-prompt-optimizer/index.js'),
  'dsh-ipad-mnemon-lite': require('../plugins/dsh-ipad-mnemon-lite/index.js'),
  'dsh-ipad-modlens-lite': require('../plugins/dsh-ipad-modlens-lite/index.js')
};

// 内存守护与自动垃圾回收 (30秒空闲周期)
setInterval(() => {
  if (typeof global.gc === 'function') {
    global.gc();
  }
}, 30000);

// 读取内置生产力 WebUI HTML
const WEB_UI_PATH = path.join(__dirname, 'webui.html');
let cachedWebUI = null;
function getWebUI() {
  if (!cachedWebUI && fs.existsSync(WEB_UI_PATH)) {
    cachedWebUI = fs.readFileSync(WEB_UI_PATH, 'utf-8');
  }
  return cachedWebUI || '<h1>Pad Harness Running</h1>';
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // 健康度与硬件探针检查
  if (req.url === '/health' || req.url === '/api/health') {
    const mem = process.memoryUsage();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      platform: 'iPadOS Rootless Standalone Server',
      arch: process.arch,
      nodeVersion: process.version,
      rssMB: Math.round(mem.rss / 1024 / 1024),
      heapUsedMB: Math.round(mem.heapUsed / 1024 / 1024),
      activePlugins: Object.keys(PLUGINS)
    }));
    return;
  }

  // 插件市场列表查询接口
  if (req.url === '/api/plugins') {
    const market = PLUGINS['dsh-ipad-market'];
    const list = await market.listMarketPlugins();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(list));
    return;
  }

  // 运行环境全量自检与工具链路体检接口
  if (req.url === '/api/env/doctor') {
    const fs = require('fs');
    const { execSync } = require('child_process');
    const mem = process.memoryUsage();

    function checkTool(cmd, aliases = []) {
      const names = [cmd, ...aliases];
      let bases = [
        '/var/jb',
        '/private/var/jb',
        '/var/run/jbroot'
      ];
      try {
        const appParents = ['/var/containers/Bundle/Application', '/private/var/containers/Bundle/Application'];
        for (const parent of appParents) {
          if (fs.existsSync(parent)) {
            for (const entry of fs.readdirSync(parent)) {
              if (entry.startsWith('.jbroot-') || entry === '.jbroot') {
                bases.unshift(`${parent}/${entry}`);
              }
            }
          }
        }
      } catch (e) {}
      try {
        const preboot = '/private/preboot';
        if (fs.existsSync(preboot)) {
          const uuids = fs.readdirSync(preboot);
          for (const u of uuids) {
            const uPath = `${preboot}/${u}`;
            try {
              const subs = fs.readdirSync(uPath);
              for (const s of subs) {
                if (s.startsWith('jb') || s.startsWith('.jbroot') || s.includes('dopamine') || s.includes('procursus')) {
                  bases.push(`${uPath}/${s}`);
                  bases.push(`${uPath}/${s}/procursus`);
                }
              }
            } catch (e) {}
          }
        }
      } catch (e) {}

      const candidatePaths = [];
      for (const n of names) {
        for (const b of bases) {
          candidatePaths.push(`${b}/bin/${n}`);
          candidatePaths.push(`${b}/usr/bin/${n}`);
          candidatePaths.push(`${b}/usr/local/bin/${n}`);
        }
        candidatePaths.push(`/bin/${n}`);
        candidatePaths.push(`/usr/bin/${n}`);
        candidatePaths.push(`/usr/local/bin/${n}`);
      }

      for (const p of candidatePaths) {
        try {
          if (fs.existsSync(p)) {
            return { found: true, path: p, version: '已就绪' };
          }
        } catch (e) {}
      }

      for (const n of names) {
        try {
          const out = execSync(`${n} --version 2>/dev/null || ${n} -v 2>/dev/null`).toString().trim();
          return { found: true, path: `PATH直接命中 (${n})`, version: out.split('\n')[0] };
        } catch (e) {}
      }
      return { found: false, path: '未检出', version: '未检出 (请检查 RootHide 白名单或在 Sileo 安装)' };
    }

    const report = {
      timestamp: new Date().toISOString(),
      status: 'ok',
      runtime: {
        platform: process.platform,
        arch: process.arch,
        nodeVersion: process.version,
        pid: process.pid,
        listenEndpoint: '0.0.0.0:3080'
      },
      dshEngine: {
        status: 'running',
        activePlugins: Object.keys(PLUGINS),
        pluginsLoaded: `${Object.keys(PLUGINS).length} / 8`
      },
      toolchains: {
        node: checkTool('node', ['node22', 'node23', 'node21', 'node20', 'node18', 'nodejs']),
        npm: checkTool('npm', ['npm22', 'npm23', 'npm21', 'npm20', 'npm18']),
        npx: checkTool('npx', ['npx22', 'npx23', 'npx21', 'npx20', 'npx18']),
        sh: checkTool('sh', ['dash', 'zsh']),
        bash: checkTool('bash', ['bash5', 'zsh']),
        python3: checkTool('python3', ['python3.12', 'python3.11', 'python3.10', 'python3.9', 'python']),
        curl: checkTool('curl'),
        git: checkTool('git')
      },
      memory: {
        rssMB: Math.round(mem.rss / 1024 / 1024),
        heapUsedMB: Math.round(mem.heapUsed / 1024 / 1024),
        heapTotalMB: Math.round(mem.heapTotal / 1024 / 1024)
      }
    };

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(report, null, 2));
    return;
  }

  // 用户自定义配置持久化与防覆盖接口
  if (req.url === '/api/user/config') {
    const fs = require('fs');
    const path = require('path');
    const docDir = process.env.HOME ? path.join(process.env.HOME, 'Documents') : process.cwd();
    const configPath = path.join(docDir, 'dsh_user_config.json');

    if (req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        try {
          const update = JSON.parse(body || '{}');
          let current = {};
          if (fs.existsSync(configPath)) {
            try { current = JSON.parse(fs.readFileSync(configPath, 'utf8')); } catch(e) {}
          }
          const merged = Object.assign({}, current, update, { updated_at: Date.now(), has_user_configured: true });
          fs.writeFileSync(configPath, JSON.stringify(merged, null, 2), 'utf8');
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ status: 'ok', saved: true }));
        } catch(e) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: e.message }));
        }
      });
      return;
    } else {
      let current = {};
      if (fs.existsSync(configPath)) {
        try { current = JSON.parse(fs.readFileSync(configPath, 'utf8')); } catch(e) {}
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(current));
      return;
    }
  }

  // 执行 POSIX 真实终端命令接口
  if (req.url === '/api/exec' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const { command, timeout } = JSON.parse(body || '{}');
        const posix = PLUGINS['dsh-ipad-posix-exec'];
        const result = await posix.execute({ command, timeout });
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // 基础对话测试、云端模型代理转发与提示词优化路由
  if (req.url === '/api/chat' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const { prompt, mode, baseUrl, apiKey, model, messages, tools } = JSON.parse(body || '{}');
        if (mode === 'optimize') {
          const opt = PLUGINS['dsh-ipad-prompt-optimizer'];
          const optimized = await opt.optimizePrompt({ prompt });
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            reply: `[Pad Harness iPad Host] 已在 iPad 本机完成任务调度。所有推理直接上云，无任何电脑依赖。`,
            optimizedPrompt: optimized.optimizedPrompt
          }));
          return;
        }

        if (apiKey && baseUrl) {
          const cleanBase = baseUrl.replace(/\/+$/, '');
          const endpoint = cleanBase.endsWith('/chat/completions') ? cleanBase : `${cleanBase}/chat/completions`;
          const payloadMsgs = (messages && messages.length) ? messages : [{ role: 'user', content: prompt }];
          const payload = {
            model: model || 'deepseek-chat',
            messages: payloadMsgs,
            stream: false
          };
          if (tools && tools.length) {
            payload.tools = tools;
          }

          const apiRes = await fetch(endpoint, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${apiKey}`
            },
            body: JSON.stringify(payload)
          });

          const data = await apiRes.json();
          res.writeHead(apiRes.status, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(data));
          return;
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          reply: `[Pad Harness iPad Host] 请在设置中配置有效 API Key 与模型通道。`
        }));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: { message: e.message } }));
      }
    });
    return;
  }

  // 远程模型列表一键拉取路由
  if (req.url === '/api/models' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const { baseUrl, apiKey } = JSON.parse(body || '{}');
        if (!baseUrl) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: { message: '请先填写 API Base URL' } }));
          return;
        }

        let cleanBase = baseUrl.replace(/\/+$/, '');
        let endpoint = cleanBase;
        if (endpoint.endsWith('/chat/completions')) {
          endpoint = endpoint.replace(/\/chat\/completions$/, '/models');
        } else if (!endpoint.endsWith('/models')) {
          endpoint = `${endpoint}/models`;
        }

        const headers = { 'Accept': 'application/json' };
        if (apiKey) headers['Authorization'] = `Bearer ${apiKey}`;

        const apiRes = await fetch(endpoint, {
          method: 'GET',
          headers: headers
        });

        const data = await apiRes.json();
        res.writeHead(apiRes.status, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data));
      } catch (e) {
        res.writeHead(502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: { message: e.message } }));
      }
    });
    return;
  }

  // 默认返回 iPad 本机内置 WebUI 交互工作台
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(getWebUI());
});

server.listen(PORT, HOST, () => {
  console.log(`[Pad Harness] Standalone Engine running on http://${HOST}:${PORT}`);
});
