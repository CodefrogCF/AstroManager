// Run from the repository root with playwright-core on NODE_PATH.
const { chromium } = require('playwright-core');
const { createServer } = require('node:http');
const { readFile } = require('node:fs/promises');
const path = require('node:path');

const root = path.resolve('build/web');
const contentTypes = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
};
const server = createServer(async (request, response) => {
  try {
    const { pathname } = new URL(request.url, 'http://127.0.0.1');
    const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(root + path.sep)) {
      response.writeHead(404).end();
      return;
    }
    const body = await readFile(file);
    response.writeHead(200, {
      'Content-Type': contentTypes[path.extname(file)] ?? 'application/octet-stream',
      'Cache-Control': 'public, max-age=3600',
    }).end(body);
  } catch (_) {
    response.writeHead(404).end();
  }
});

async function timeFirstFrame(page, navigate) {
  await navigate();
  await page.waitForFunction(() => window.firstFlutterFrameMs !== undefined);
  return await page.evaluate(() => window.firstFlutterFrameMs);
}

async function main() {
  await readFile(path.join(root, 'index.html'));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const browser = await chromium.launch({
      channel: 'chrome',
      headless: true,
      args: [
        '--no-proxy-server',
        '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1',
        '--use-angle=swiftshader',
        '--enable-unsafe-swiftshader',
      ],
    });
    try {
      console.log('Chrome', browser.version());
      const startup = [];
      const reload = [];
      const origin = 'http://127.0.0.1:' + server.address().port;
      for (let sample = 0; sample < 8; sample++) {
        const context = await browser.newContext({ serviceWorkers: 'block' });
        try {
          await context.addInitScript(() => {
            window.addEventListener('flutter-first-frame', () => {
              window.firstFlutterFrameMs = performance.now();
            }, { once: true });
          });
          const page = await context.newPage();
          startup.push(await timeFirstFrame(page, () => page.goto(origin)));
          reload.push(await timeFirstFrame(page, () => page.reload()));
        } finally {
          await context.close();
        }
      }
      for (const [label, results] of [['New context', startup], ['Reload', reload]]) {
        results.sort((a, b) => a - b);
        const percentile = probability => results[Math.ceil(results.length * probability) - 1].toFixed(0);
        console.log(`${label} (n=${results.length}): p50 ${percentile(0.5)} ms, p95 ${percentile(0.95)} ms`);
      }
    } finally {
      await browser.close();
    }
  } finally {
    server.close();
  }
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
