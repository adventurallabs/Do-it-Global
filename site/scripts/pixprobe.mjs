// Dev-only: scrolls every pinned DeviceStory down and back up with the wheel
// and screenshots the device's screen each step, flagging frames where the
// screen is painted as a flat colour (blank) instead of app UI. Unlike
// storyprobe.mjs this reads real pixels, so it also catches raster/paint
// blanks that computed styles can't see.
// Usage: node scripts/pixprobe.mjs <url> <w>x<h> [--mobile] [--webkit] [--delta n] [--wait ms] [--out dir]
// --webkit runs Safari's engine (needs: npx playwright-core install webkit).
import { chromium, webkit } from 'playwright-core'
import { mkdirSync, writeFileSync } from 'node:fs'
import { PNG } from './png.mjs'

const args = process.argv.slice(2)
const url = args[0]
const [w, h] = (args[1] ?? '1440x900').split('x').map(Number)
const mobile = args.includes('--mobile')
const opt = (k, d) => (args.includes(k) ? args[args.indexOf(k) + 1] : d)
const delta = Number(opt('--delta', 140))
const wait = Number(opt('--wait', 60))
const out = opt('--out', null)
if (out) mkdirSync(out, { recursive: true })

const browser = args.includes('--webkit')
  ? await webkit.launch({ headless: true })
  : await chromium.launch({
      executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
      args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist'],
      headless: true,
    })
const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: mobile ? 2 : 1, ...(args.includes('--webkit') ? {} : { isMobile: mobile }), hasTouch: mobile })
const errors = []
page.on('pageerror', (e) => errors.push(e.message))
await page.goto(url, { waitUntil: 'networkidle' })
await page.waitForTimeout(2500)
await page.mouse.move(w / 2, h / 2)

// Screen rect of the pinned story on screen (device fully visible), or null.
const screenRect = () =>
  page.evaluate(() => {
    for (const sec of document.querySelectorAll('section')) {
      const s = sec.querySelector('[data-screen]')
      if (!s) continue
      const r = sec.getBoundingClientRect()
      if (r.top > 0 || r.bottom < innerHeight) continue
      const dev = sec.querySelector('.device-3d')
      if (+getComputedStyle(dev).opacity < 0.99) continue
      const b = s.parentElement.getBoundingClientRect()
      if (b.top < 0 || b.bottom > innerHeight || b.width < 40) continue
      // Inset: skip rounded corners, notch and bezel edges.
      const ix = b.width * 0.12, iy = b.height * 0.12
      return { id: sec.id, top: Math.round(-r.top), x: b.left + ix, y: b.top + iy, width: b.width - 2 * ix, height: b.height - 2 * iy }
    }
    return null
  })

const bad = []
let frames = 0
const sample = async (tag) => {
  const r = await screenRect()
  if (!r) return
  const buf = await page.screenshot({ clip: { x: r.x, y: r.y, width: r.width, height: r.height }, scale: 'css' })
  const { sd } = PNG.lumaStats(buf)
  frames++
  if (sd < 6) {
    const y = await page.evaluate(() => scrollY)
    bad.push(`${tag} ${r.id}@${r.top} y=${y} sd=${sd.toFixed(1)}`)
    if (out) writeFileSync(`${out}/blank-${bad.length}.png`, buf)
  }
}

const run = async (dir, tag) => {
  let last = -1, same = 0
  for (let i = 0; i < 5000; i++) {
    await page.mouse.wheel(0, dir * delta)
    await page.waitForTimeout(wait)
    const y = await page.evaluate(() => scrollY)
    same = y === last ? same + 1 : 0
    last = y
    if (same > 12) break
    await sample(tag)
  }
}
await run(1, 'DOWN')
await page.waitForTimeout(1200)
await run(-1, 'UP  ')
// Direction flips inside each story: down a bit, up a bit, repeatedly.
const tops = await page.evaluate(() => [...document.querySelectorAll('section')].filter((s) => s.querySelector('[data-screen]')).map((s) => [s.offsetTop, s.offsetHeight]))
for (const [top, hgt] of tops) {
  await page.evaluate((y) => scrollTo(0, y), top + hgt * 0.75)
  await page.waitForTimeout(1500)
  for (let k = 0; k < 40; k++) {
    const dir = k % 8 < 4 ? -1 : 1
    await page.mouse.wheel(0, dir * delta * (1 + (k % 3)))
    await page.waitForTimeout(wait)
    await sample('FLIP')
  }
  for (let k = 0; k < 10; k++) {
    await page.waitForTimeout(250)
    await sample('SETL')
  }
}
console.log(`${frames} frames sampled`)
console.log(bad.length ? `BLANK SCREEN FRAMES (${bad.length}):\n` + bad.slice(0, 80).join('\n') : 'no blank screen frames')
if (errors.length) console.log('page errors:\n' + errors.join('\n'))
await browser.close()
