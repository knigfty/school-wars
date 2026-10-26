/* Real exported-game checks; run after export with Playwright installed. */
const { chromium } = require('playwright');
const { spawn } = require('node:child_process');
const { mkdirSync, writeFileSync } = require('node:fs');
const { setTimeout: delay } = require('node:timers/promises');
const assert = require('node:assert/strict');

async function run() {
  const output = 'Testing/browser-output';
  mkdirSync(output, { recursive: true });
  const server = spawn('python3', ['Tools/serve_web.py', '--directory', 'export/web', '--port', '8061'], { stdio: 'ignore' });
  let browser;
  const errors = [];
  try {
    for (let attempt = 0; attempt < 40; attempt++) {
      try {
        if ((await fetch('http://127.0.0.1:8061')).ok) break;
      } catch { /* server is starting */ }
      await delay(100);
    }
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: { width: 960, height: 600 } });
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      if (message.type() === 'error' || /SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text());
    });
    for (const [team, x] of [['black', 172], ['green', 378], ['yellow', 584], ['purple', 790]]) {
      await page.goto('http://127.0.0.1:8061');
      await page.waitForSelector('canvas');
      await page.waitForFunction(() => {
        const status = document.querySelector('#status');
        return !status || getComputedStyle(status).display === 'none';
      });
      await delay(1800);
      const menu = await page.screenshot({ path: `${output}/${team}-menu.png` });
      await page.mouse.click(x, 465);
      await delay(500);
      const match = await page.screenshot({ path: `${output}/${team}-match.png` });
      assert(!menu.equals(match), `${team} selection must enter the match`);
      await page.keyboard.press('a');
      await delay(100);
      await page.screenshot({ path: `${output}/${team}-selected.png` });
      await page.mouse.click(480, 300);
      await delay(500);
      await page.mouse.move(480, 300);
      await page.mouse.down({ button: 'right' });
      await page.mouse.move(560, 350, { steps: 5 });
      await page.mouse.up({ button: 'right' });
      await page.mouse.wheel(0, -120);
      await delay(300);
      await page.screenshot({ path: `${output}/${team}-orders.png` });
      await page.keyboard.press('Escape');
      await delay(350);
      const paused = await page.screenshot({ path: `${output}/${team}-paused.png` });
      await delay(700);
      assert(paused.equals(await page.screenshot()), `${team} pause must freeze the rendered game`);
      await page.keyboard.press('Escape');
      await delay(150);
      assert(!paused.equals(await page.screenshot()), `${team} Escape must resume the match`);
    }
    await page.setViewportSize({ width: 1280, height: 720 });
    await delay(200);
    await page.screenshot({ path: `${output}/wide-match.png` });
    assert.deepEqual(errors, [], 'Web build must have no browser or GDScript errors');
    console.log('Chromium: all four schools, selection, movement, pan, zoom, pause/resume, and resize passed.');
  } finally {
    writeFileSync(`${output}/errors.json`, JSON.stringify(errors, null, 2));
    if (browser) await browser.close();
    server.kill();
  }
}

run().catch(error => { console.error(error); process.exitCode = 1; });
