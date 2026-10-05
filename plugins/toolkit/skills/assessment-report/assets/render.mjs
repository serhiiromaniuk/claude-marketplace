// Canonical HTML -> PDF renderer for the assessment-report skill.
// Drives headless Chrome over the DevTools Protocol (Node >= 22, global WebSocket)
// so the PDF gets:
//   - footer page numbers    (displayHeaderFooter + footerTemplate)
//   - bookmarks / outline     (generateDocumentOutline, from <h1>-<h3> only)
//   - tagged (accessible) PDF (generateTaggedPDF)
//   - exact CSS @page margins (preferCSSPageSize)
//
// Usage:
//   node render.mjs <input.html> <output.pdf> ["Footer left text"] [--port N]
//
// By default it launches its own throwaway headless Chrome (temp profile, random
// debugging port) and shuts it down afterwards. Chrome is found via $CHROME, then
// the usual install paths for Linux / macOS / Windows. CHROME_NO_SANDBOX=1 adds
// --no-sandbox (automatic when running as root, e.g. in a container).
// --port N (or the old four-argument form <in> <out> <port> "footer") instead
// reuses a Chrome you already started with --remote-debugging-port=N.
//
// Exit codes: 0 PDF written · 1 render failed · 2 usage / environment error.
//
// Always standardize on THIS renderer (not `chrome --print-to-pdf`): the CLI flag
// uses different default margins and omits header/footer, which shifts layout.
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const USAGE = 'usage: node render.mjs <input.html> <output.pdf> ["footer left text"] [--port N]';
const LOAD_TIMEOUT_MS = 30_000;
const RPC_TIMEOUT_MS = 60_000;
const LAUNCH_TIMEOUT_MS = 20_000;

const fail = (code, msg) => { const e = new Error(msg); e.exitCode = code; return e; };

function parseArgs(argv) {
  const pos = [];
  let port = null;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--port') port = argv[++i];
    else if (argv[i] === '-h' || argv[i] === '--help') { console.log(USAGE); process.exit(0); }
    else pos.push(argv[i]);
  }
  // Old convention: <in> <out> <port> "footer". Only with all four, so a numeric
  // footer such as "2026" is still a footer.
  if (port === null && pos.length === 4 && /^\d+$/.test(pos[2])) port = pos.splice(2, 1)[0];
  const [htmlPath, outPath, footerLeft = 'Confidential'] = pos;
  if (!htmlPath || !outPath || pos.length > 3) throw fail(2, USAGE);
  if (port !== null && !/^\d+$/.test(port)) throw fail(2, `--port must be a number, got "${port}"`);
  return { htmlPath: resolve(htmlPath), outPath: resolve(outPath), footerLeft, port };
}

const escapeHtml = s => s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function onPath(name) {
  for (const dir of (process.env.PATH || '').split(delimiter)) {
    const p = join(dir, name);
    if (dir && existsSync(p)) return p;
  }
  return null;
}

function findChrome() {
  if (process.env.CHROME) {
    if (!existsSync(process.env.CHROME)) throw fail(2, `CHROME=${process.env.CHROME} does not exist`);
    return process.env.CHROME;
  }
  const candidates = {
    linux: () => ['google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser'].map(onPath),
    darwin: () => ['/Applications', join(process.env.HOME || '', 'Applications')].flatMap(d => [
      `${d}/Google Chrome.app/Contents/MacOS/Google Chrome`,
      `${d}/Chromium.app/Contents/MacOS/Chromium`,
    ]),
    win32: () => [process.env.PROGRAMFILES, process.env['PROGRAMFILES(X86)'], process.env.LOCALAPPDATA]
      .filter(Boolean).flatMap(d => [
        join(d, 'Google', 'Chrome', 'Application', 'chrome.exe'),
        join(d, 'Microsoft', 'Edge', 'Application', 'msedge.exe'),
      ]),
  }[process.platform];
  const found = (candidates ? candidates() : []).find(p => p && existsSync(p));
  if (!found) throw fail(2, `no Chrome/Chromium found for ${process.platform} — set CHROME=/path/to/chrome`);
  return found;
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function launchChrome() {
  const bin = findChrome();
  const profile = mkdtempSync(join(tmpdir(), 'ar-render-'));
  const args = ['--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
    `--user-data-dir=${profile}`, '--remote-debugging-port=0', 'about:blank'];
  // Chrome refuses to start sandboxed as root (containers, CI); some distro
  // builds also need it off — opt in with CHROME_NO_SANDBOX=1.
  if (process.getuid?.() === 0 || process.env.CHROME_NO_SANDBOX === '1') args.unshift('--no-sandbox');
  const proc = spawn(bin, args, { stdio: ['ignore', 'ignore', 'pipe'] });
  let stderr = '';
  proc.stderr.on('data', d => { stderr = (stderr + d).slice(-4000); });
  let exited = false;
  proc.on('exit', () => { exited = true; });
  proc.on('error', e => { exited = true; stderr += String(e); });

  const portFile = join(profile, 'DevToolsActivePort');
  const deadline = Date.now() + LAUNCH_TIMEOUT_MS;
  while (Date.now() < deadline && !exited) {
    if (existsSync(portFile)) {
      const [port, path] = readFileSync(portFile, 'utf8').split('\n');
      if (port && path) return { proc, profile, wsUrl: `ws://127.0.0.1:${port.trim()}${path.trim()}` };
    }
    await sleep(100);
  }
  await stopChrome({ proc, profile });
  throw fail(1, `Chrome did not start (${bin}).${stderr ? `\n${stderr.trim()}` : ''}`);
}

async function stopChrome(chrome) {
  if (!chrome) return;
  const { proc, profile } = chrome;
  if (proc && proc.exitCode === null && proc.signalCode === null) {
    const gone = new Promise(r => proc.once('exit', r));
    proc.kill('SIGTERM');
    if (await Promise.race([gone.then(() => true), sleep(5000).then(() => false)]) === false) {
      proc.kill('SIGKILL');
      await Promise.race([gone, sleep(2000)]);
    }
  }
  if (profile) rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}

function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  const waiters = new Map();
  const listeners = [];
  let seq = 1;
  const closed = new Promise(r => ws.addEventListener('close', r, { once: true }));
  ws.addEventListener('message', ev => {
    const m = JSON.parse(ev.data);
    if (m.id && waiters.has(m.id)) {
      const { res, rej, timer } = waiters.get(m.id);
      waiters.delete(m.id); clearTimeout(timer);
      m.error ? rej(fail(1, `CDP error: ${m.error.message}${m.error.data ? ` (${m.error.data})` : ''}`)) : res(m.result);
    } else if (m.method) listeners.forEach(fn => fn(m));
  });
  closed.then(() => waiters.forEach(({ rej }) => rej(fail(1, 'DevTools connection closed'))));
  const rpc = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const id = seq++;
    const timer = setTimeout(() => { waiters.delete(id); rej(fail(1, `CDP ${method} timed out`)); }, RPC_TIMEOUT_MS);
    waiters.set(id, { res, rej, timer });
    ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  });
  const opened = new Promise((res, rej) => {
    ws.addEventListener('open', res, { once: true });
    ws.addEventListener('error', () => rej(fail(1, `cannot connect to Chrome DevTools at ${wsUrl}`)), { once: true });
  });
  return { ws, rpc, opened, on: fn => listeners.push(fn) };
}

async function render({ htmlPath, outPath, footerLeft }, wsUrl) {
  const cdp = connect(wsUrl);
  await cdp.opened;
  let targetId = null;
  try {
    ({ targetId } = await cdp.rpc('Target.createTarget', { url: 'about:blank' }));
    const { sessionId } = await cdp.rpc('Target.attachToTarget', { targetId, flatten: true });
    let loaded = false;
    cdp.on(m => { if (m.sessionId === sessionId && m.method === 'Page.loadEventFired') loaded = true; });
    await cdp.rpc('Page.enable', {}, sessionId);

    const nav = await cdp.rpc('Page.navigate', { url: pathToFileURL(htmlPath).href }, sessionId);
    if (nav.errorText) throw fail(1, `Chrome could not load ${htmlPath}: ${nav.errorText}`);
    const deadline = Date.now() + LOAD_TIMEOUT_MS;
    while (!loaded && Date.now() < deadline) await sleep(100);
    if (!loaded) throw fail(1, `page did not finish loading within ${LOAD_TIMEOUT_MS / 1000}s`);

    // Wait for fonts, then keep h4–h6 labels out of the PDF outline: only
    // h1–h3 become bookmarks, so the outline lists sections, not every eyebrow.
    await cdp.rpc('Runtime.evaluate', {
      expression: `document.fonts.ready.then(() => {
        document.querySelectorAll('h4,h5,h6').forEach(h => { if (!h.hasAttribute('role')) h.setAttribute('role', 'presentation'); });
      })`,
      awaitPromise: true,
    }, sessionId);
    await sleep(300); // settle SVG layout

    const footer = `<div style="width:100%;font-size:7px;color:#94a3b8;padding:0 12mm;
      display:flex;justify-content:space-between;font-family:Helvetica,Arial,sans-serif;">
      <span>${escapeHtml(footerLeft)}</span>
      <span>Page <span class="pageNumber"></span> / <span class="totalPages"></span></span></div>`;
    const { data } = await cdp.rpc('Page.printToPDF', {
      printBackground: true,
      preferCSSPageSize: true,
      displayHeaderFooter: true,
      headerTemplate: '<span></span>',
      footerTemplate: footer,
      generateDocumentOutline: true,
      generateTaggedPDF: true,
    }, sessionId);
    const pdf = Buffer.from(data || '', 'base64');
    if (pdf.length === 0) throw fail(1, 'Chrome returned an empty PDF');
    writeFileSync(outPath, pdf);
    return pdf.length;
  } finally {
    if (targetId) await cdp.rpc('Target.closeTarget', { targetId }).catch(() => {});
    cdp.ws.close();
  }
}

async function main() {
  if (typeof WebSocket !== 'function') {
    throw fail(2, `Node >= 22 required (needs the global WebSocket); this is Node ${process.versions.node}`);
  }
  const opts = parseArgs(process.argv.slice(2));
  if (!existsSync(opts.htmlPath) || !statSync(opts.htmlPath).isFile()) throw fail(2, `input not found: ${opts.htmlPath}`);
  if (!existsSync(dirname(opts.outPath))) throw fail(2, `output directory does not exist: ${dirname(opts.outPath)}`);

  let chrome = null;
  const cleanup = () => stopChrome(chrome).catch(() => {});
  for (const sig of ['SIGINT', 'SIGTERM']) process.once(sig, () => cleanup().then(() => process.exit(130)));
  try {
    let wsUrl;
    if (opts.port) {
      const res = await fetch(`http://127.0.0.1:${opts.port}/json/version`).catch(() => null);
      if (!res?.ok) throw fail(1, `no Chrome DevTools endpoint on port ${opts.port}`);
      wsUrl = (await res.json()).webSocketDebuggerUrl;
    } else {
      chrome = await launchChrome();
      wsUrl = chrome.wsUrl;
    }
    const bytes = await render(opts, wsUrl);
    console.log(`PDF written: ${opts.outPath} (${bytes} bytes)`);
  } finally {
    await cleanup();
  }
}

main().then(() => process.exit(0), e => {
  console.error(`render.mjs: ${e.message}`);
  process.exit(e.exitCode ?? 1);
});
