/**
 * dsh-ipad-mnemon-lite
 * 对标 dsh-mnemon，磁盘 SQLite / JSON 优先轻量记忆图谱
 * 内存硬限制 < 30MB，用完立即释放
 */
const fs = require('fs');
const path = require('path');

const MEMORY_FILE = process.env.DSH_MEMORY_PATH || '/var/jb/var/dsh/memory.json';

module.exports = {
  name: 'dsh-ipad-mnemon-lite',
  description: 'Pad Harness 轻量级记忆图谱与知识检索插件',
  
  async remember({ key, content, category = 'fact' }) {
    let store = {};
    try {
      if (fs.existsSync(MEMORY_FILE)) {
        store = JSON.parse(fs.readFileSync(MEMORY_FILE, 'utf8'));
      }
    } catch (_) {}

    store[key] = {
      content,
      category,
      updatedAt: Date.now()
    };

    try {
      const dir = path.dirname(MEMORY_FILE);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(MEMORY_FILE, JSON.stringify(store, null, 2), 'utf8');
      return { success: true, key };
    } catch (e) {
      return { success: false, error: e.message };
    }
  },

  async recall({ query, limit = 5 }) {
    try {
      if (!fs.existsSync(MEMORY_FILE)) return { results: [] };
      const store = JSON.parse(fs.readFileSync(MEMORY_FILE, 'utf8'));
      const q = (query || '').toLowerCase();
      const matches = Object.entries(store)
        .filter(([k, v]) => k.toLowerCase().includes(q) || (v.content && v.content.toLowerCase().includes(q)))
        .slice(0, limit)
        .map(([k, v]) => ({ key: k, ...v }));
      return { results: matches };
    } catch (e) {
      return { results: [], error: e.message };
    }
  }
};