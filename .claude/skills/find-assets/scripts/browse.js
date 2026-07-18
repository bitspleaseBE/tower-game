#!/usr/bin/env node
// Asset-site browsing helper with graceful degradation.
//
//   node browse.js dump <url> [out.html]              rendered page HTML (falls back to raw curl HTML)
//   node browse.js shot <url> [out.png]               screenshot (interactive mode only)
//   node browse.js download <pageUrl> <pattern> <out> open page, click download link/button matching
//                                                     /pattern/i, save the file (interactive mode only)
//   node browse.js get <fileUrl> <out>                direct file download (curl; works everywhere)
//
// Interactive mode needs the `playwright` npm package plus a Chromium
// (preinstalled at /opt/pw-browsers/chromium in Claude sandboxes, or
// `npx playwright install chromium` locally). Some sandboxed environments
// block full-browser TLS at the egress proxy (net::ERR_CONNECTION_RESET on
// every navigation) — in that case dump/get still work via curl, and
// shot/download report NET_BLOCKED so the caller can switch strategy.

const { execFileSync } = require('child_process');
const fs = require('fs');

const [, , cmd, ...rest] = process.argv;

function curl(url, outfile) {
  execFileSync('curl', ['-sSL', '--fail', '--retry', '2', '--max-time', '90', '-o', outfile, url], { stdio: 'inherit' });
  console.log('CURL OK ->', outfile);
}

async function withPage(fn) {
  let pw;
  try { pw = require('playwright'); }
  catch { throw new Error('NO_PLAYWRIGHT: npm install playwright (and locally: npx playwright install chromium)'); }
  const exe = '/opt/pw-browsers/chromium';
  const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
  const browser = await pw.chromium.launch({
    ...(fs.existsSync(exe) ? { executablePath: exe } : {}),
    args: ['--no-sandbox'],
    ...(proxy ? { proxy: { server: proxy } } : {}),
  });
  try {
    const ctx = await browser.newContext({ acceptDownloads: true });
    return await fn(await ctx.newPage());
  } finally {
    await browser.close();
  }
}

function isNetBlocked(e) {
  return /ERR_CONNECTION_RESET|ERR_TUNNEL_CONNECTION_FAILED|ERR_PROXY/.test(e.message);
}

(async () => {
  if (cmd === 'get') {
    const [url, out] = rest;
    return curl(url, out);
  }

  if (cmd === 'dump') {
    const [url, out = 'page.html'] = rest;
    try {
      await withPage(async (page) => {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
        await page.waitForTimeout(2000);
        fs.writeFileSync(out, await page.content());
        console.log('BROWSER OK ->', out);
      });
    } catch (e) {
      console.log(isNetBlocked(e) ? 'NET_BLOCKED, falling back to curl (raw HTML, no JS rendering)'
                                  : `browser unavailable (${e.message.split('\n')[0]}), falling back to curl`);
      curl(url, out);
    }
    return;
  }

  if (cmd === 'shot') {
    const [url, out = 'page.png'] = rest;
    try {
      await withPage(async (page) => {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
        await page.waitForTimeout(2500);
        await page.screenshot({ path: out, fullPage: false });
        console.log('SHOT OK ->', out);
      });
    } catch (e) {
      console.log(isNetBlocked(e) ? 'NET_BLOCKED: no screenshots in this environment — use dump + preview-image get instead'
                                  : 'FAIL: ' + e.message.split('\n')[0]);
      process.exit(1);
    }
    return;
  }

  if (cmd === 'download') {
    const [pageUrl, pattern, out] = rest;
    try {
      await withPage(async (page) => {
        await page.goto(pageUrl, { waitUntil: 'load', timeout: 45000 });
        await page.waitForTimeout(1500);
        const re = new RegExp(pattern, 'i');
        const [download] = await Promise.all([
          page.waitForEvent('download', { timeout: 30000 }),
          (async () => {
            const link = page.getByRole('link', { name: re }).first();
            const btn = page.getByRole('button', { name: re }).first();
            if (await link.count()) await link.click();
            else if (await btn.count()) await btn.click();
            else throw new Error('no link/button matching /' + pattern + '/i');
          })(),
        ]);
        await download.saveAs(out);
        console.log('DOWNLOAD OK ->', out);
      });
    } catch (e) {
      console.log(isNetBlocked(e)
        ? 'NET_BLOCKED: interactive downloads unavailable — find a direct file URL in the dumped HTML and use `get`, or mark the proposal manual-download'
        : 'FAIL: ' + e.message.split('\n')[0]);
      process.exit(1);
    }
    return;
  }

  console.log('usage: browse.js dump|shot|download|get ... (see header comment)');
  process.exit(2);
})();
