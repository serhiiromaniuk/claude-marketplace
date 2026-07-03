// Canonical HTML -> PDF renderer for the assessment-report skill.
// Uses Chrome DevTools Protocol (Node 18+ global WebSocket) so the PDF gets:
//   - footer page numbers   (displayHeaderFooter + footerTemplate)
//   - bookmarks / outline    (generateDocumentOutline, from <h1>-<h6>)
//   - tagged (accessible) PDF (generateTaggedPDF)
//   - exact CSS @page margins (preferCSSPageSize)
//
// Usage:
//   1) start Chrome headless with remote debugging, e.g.
//        google-chrome --headless=new --disable-gpu --no-sandbox \
//          --remote-debugging-port=9333 --remote-allow-origins=* about:blank &
//   2) node render.mjs <input.html> <output.pdf> <port> ["Footer left text"]
//
// Always standardize on THIS renderer (not `chrome --print-to-pdf`): the CLI flag
// uses different default margins and omits header/footer, which shifts layout.
import { writeFileSync } from 'node:fs';

const [,, htmlPath, outPath, port, footerLeftArg] = process.argv;
if (!htmlPath || !outPath || !port) {
  console.error('usage: node render.mjs <input.html> <output.pdf> <port> ["footer left text"]');
  process.exit(1);
}
const footerLeft = footerLeftArg || 'Confidential';
const base = `http://127.0.0.1:${port}`;

const ver = await (await fetch(`${base}/json/version`)).json();
const ws = new WebSocket(ver.webSocketDebuggerUrl);
const waiters = new Map();
let seq = 1, loaded = false, sessionId = null;
const rpc = (method, params, sid) => new Promise(res => {
  const id = seq++; waiters.set(id, res);
  ws.send(JSON.stringify({ id, method, params, ...(sid ? { sessionId: sid } : {}) }));
});

await new Promise(r => ws.addEventListener('open', r, { once: true }));
ws.addEventListener('message', ev => {
  const m = JSON.parse(ev.data);
  if (m.id && waiters.has(m.id)) { waiters.get(m.id)(m.result); waiters.delete(m.id); }
  if (m.method === 'Page.loadEventFired') loaded = true;
});

const { targetId } = await rpc('Target.createTarget', { url: 'about:blank' });
sessionId = (await rpc('Target.attachToTarget', { targetId, flatten: true })).sessionId;
await rpc('Page.enable', {}, sessionId);
await rpc('Page.navigate', { url: `file://${htmlPath}` }, sessionId);
for (let i = 0; i < 100 && !loaded; i++) await new Promise(r => setTimeout(r, 100));
await new Promise(r => setTimeout(r, 800)); // settle fonts/SVG

const footer = `<div style="width:100%;font-size:7px;color:#94a3b8;padding:0 12mm;
  display:flex;justify-content:space-between;font-family:Helvetica,Arial,sans-serif;">
  <span>${footerLeft}</span>
  <span>Page <span class="pageNumber"></span> / <span class="totalPages"></span></span></div>`;

const { data } = await rpc('Page.printToPDF', {
  printBackground: true,
  preferCSSPageSize: true,
  displayHeaderFooter: true,
  headerTemplate: '<span></span>',
  footerTemplate: footer,
  generateDocumentOutline: true,
  generateTaggedPDF: true,
}, sessionId);

writeFileSync(outPath, Buffer.from(data, 'base64'));
console.log('PDF written:', outPath);
ws.close();
process.exit(0);
