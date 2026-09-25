// Dev-only: walks the whole page in small steps (like a finger scroll) and
// flags any frame that renders mostly white/blank, plus horizontal overflow.
// Usage: node scripts/scan.mjs <url> <w>x<h> [--mobile] [--out dir] [--steps n]
import { chromium } from 'playwright-core'
import { mkdirSync } from 'node:fs'
import { PNG } from './png.mjs'

const args = process.argv.slice(2)
const url = args[0]
const [w, h] = (args[1] ?? '390x844').split('x').map(Number)
const mobile = args.includes('--mobile')
const out = args.includes('--out') ? args[args.indexOf('--out') + 1] : null
const steps = args.includes('--steps') ? Number(args[args.indexOf('--steps') + 1]) : 60
if (out) mkdirSync(out, { recursive: true })

const browser = await chromium.launch({
  executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist'],
  headless: true,
})
const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: mobile ? 2 : 1, isMobile: mobile, hasTouch: mobile })
const errors = []
page.on('console', (m) => (m.type() === 'error' || m.type() === 'warning') && errors.push(`[${m.type()}] ${m.text()}`))
page.on('pageerror', (e) => errors.push(`[pageerror] ${e.message}`))
await page.goto(url, { waitUntil: 'networkidle' })
await page.waitForTimeout(3000)

const info = await page.evaluate(() => ({
  total: document.documentElement.scrollHeight - innerHeight,
  overflowX: document.documentElement.scrollWidth - innerWidth,
}))
console.log('scrollable', info.total, 'overflowX', info.overflowX)

const bad = []
for (let i = 0; i <= steps; i++) {
  const y = Math.round((info.total * i) / steps)
  await page.evaluate((t) => scrollTo(0, t), y)
  await page.waitForTimeout(350)
  const buf = await page.screenshot({ scale: 'css' })
  const lum = PNG.meanLuma(buf)
  const wide = await page.evaluate(() => {
    const vw = innerWidth
    const hits = []
    for (const el of document.querySelectorAll('main *')) {
      const r = el.getBoundingClientRect()
      if (r.width && r.bottom > 0 && r.top < innerHeight && (r.right > vw + 1 || r.left < -1)) {
        const st = getComputedStyle(el)
        if (st.visibility !== 'hidden' && st.opacity !== '0') hits.push(`${el.tagName.toLowerCase()}.${String(el.className).slice(0, 40)} ${Math.round(r.left)}..${Math.round(r.right)}`)
      }
    }
    return hits.slice(0, 3)
  })
  const flag = lum.white > 0.5 ? 'WHITE' : lum.mean < 3 ? 'BLACK' : ''
  if (flag) bad.push(`${i} y=${y} ${flag}`)
  console.log(String(i).padStart(3), 'y', y, 'mean', lum.mean.toFixed(1), 'white%', (lum.white * 100).toFixed(0), flag, wide.length ? 'OVERFLOW ' + wide.join(' | ') : '')
  if (out) await page.screenshot({ path: `${out}/${String(i).padStart(3, '0')}.png`, scale: 'css' })
}
console.log(bad.length ? 'FLAGGED:\n' + bad.join('\n') : 'no blank frames')
console.log(errors.length ? [...new Set(errors)].slice(0, 20).join('\n') : 'no console errors')
await browser.close()
