const { spawn } = require('child_process');
const fs = require('fs');

function resolveJbEnv() {
  const bases = ['/var/jb', '/private/var/jb', '/var/run/jbroot'];
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
              bases.unshift(`${uPath}/${s}`);
              bases.unshift(`${uPath}/${s}/procursus`);
            }
          }
        } catch (e) {}
      }
    }
  } catch (e) {}

  let shPath = '/bin/sh';
  const pathList = [];

  for (const b of bases) {
    pathList.push(`${b}/bin`, `${b}/usr/bin`, `${b}/usr/local/bin`);
    if (shPath === '/bin/sh') {
      if (fs.existsSync(`${b}/bin/bash`)) {
        shPath = `${b}/bin/bash`;
      } else if (fs.existsSync(`${b}/bin/sh`)) {
        shPath = `${b}/bin/sh`;
      }
    }
  }
  pathList.push('/bin', '/usr/bin', '/usr/local/bin');

  return {
    shPath,
    envPath: pathList.join(':')
  };
}

module.exports = {
  name: 'dsh-ipad-posix-exec',
  description: 'Execute native POSIX shell commands under Dopamine Rootless and RootHide randomized jbroot',
  async execute({ command, timeout = 30000 }) {
    return new Promise((resolve) => {
      const { shPath, envPath } = resolveJbEnv();
      const child = spawn(shPath, ['-c', command], {
        env: {
          ...process.env,
          PATH: envPath
        }
      });

      let stdout = '';
      let stderr = '';
      let timer = null;

      if (timeout > 0) {
        timer = setTimeout(() => {
          child.kill('SIGTERM');
          resolve({ exitCode: -1, stdout, stderr: stderr + '\n[Command timed out]' });
        }, timeout);
      }

      child.stdout.on('data', (d) => { stdout += d.toString(); });
      child.stderr.on('data', (d) => { stderr += d.toString(); });

      child.on('close', (code) => {
        if (timer) clearTimeout(timer);
        resolve({ exitCode: code, stdout, stderr });
      });

      child.on('error', (err) => {
        if (timer) clearTimeout(timer);
        resolve({ exitCode: -1, stdout, stderr: err.message });
      });
    });
  }
};
