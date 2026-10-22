const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const path = require('node:path');

test('managed server binds to loopback and exits when its parent closes stdin', { timeout: 20000 }, async (t) => {
  const child = spawn(process.execPath, [path.join(__dirname, '..', 'server.js')], {
    env: { ...process.env, HOST: '127.0.0.1', PORT: '0', API_TOKENS: 'managed-test-token', POPCORN_MANAGED_SERVER: '1' },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  const exited = once(child, 'exit');
  t.after(() => { if (child.exitCode === null) child.kill(); });
  let output = '';
  let errors = '';
  child.stderr.on('data', (chunk) => { errors += chunk; });
  const address = await new Promise((resolve, reject) => {
    child.stdout.on('data', (chunk) => {
      output += chunk;
      const match = output.match(/Player available at (http:\/\/127\.0\.0\.1:\d+)\//);
      if (match) resolve(match[1]);
    });
    child.once('error', reject);
    child.once('exit', (code) => reject(new Error(`Server exited ${code}: ${errors}`)));
  });
  assert.equal((await fetch(`${address}/health`)).status, 200);
  assert.equal((await fetch(`${address}/providers`)).status, 401);
  const response = await fetch(`${address}/providers`, { headers: { Authorization: 'Bearer managed-test-token' } });
  assert.equal(response.status, 200);
  assert.ok((await response.json()).providers.length);
  child.stdin.end();
  assert.deepEqual(await exited, [0, null]);
  assert.match(output, /parent closed; closing HTTP server/);
  await assert.rejects(fetch(`${address}/health`));
});
