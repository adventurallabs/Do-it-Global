// Dev-only visual check: screenshots a page at several scroll depths and
// prints any console errors. Usage:
//   node scripts/shoot.mjs <url> <outDir> <w>x<h> <fractions comma-separated> [--mobile]
import { chromium } from 'playwright-core'
import { mkdirSync } from 'node:fs'

const [url, out = 'shots', size = '1440x900', fr = '0,0.2,0.4,0.6,0.8,1'] = process.argv.slice(2)
const mobile = process.argv.includes('--mobile')
const reduced = process.argv.includes('--reduced')
const [w, h] = size.split('x').map(Number)
mkdirSync(out, { recursive: true })

const browser = await chromium.launch({
  executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist'],
  headless: true,
})
const page = await browser.newPage({
  viewport: { width: w, height: h },
  deviceScaleFactor: 1,
  isMobile: mobile,
  hasTouch: mobile,
  reducedMotion: reduced ? 'reduce' : 'no-preference',
})
const errors = []
page.on('console', (m) => (m.type() === 'error' || m.type() === 'warning') && errors.push(`[${m.type()}] ${m.text()}`))
page.on('pageerror', (e) => errors.push(`[pageerror] ${e.message}`))
await page.goto(url, { waitUntil: 'networkidle' })
await page.waitForTimeout(3500)
const total = await page.evaluate(() => document.documentElement.scrollHeight - innerHeight)
console.log('scrollable', total)
for (const f of fr.split(',').map(Number)) {
  const y = Math.round(total * f)
  // Step there so scroll-scrubbed timelines pass through each state.
  await page.evaluate(async (target) => {
    const start = scrollY
    const steps = 12
    for (let i = 1; i <= steps; i++) {
      scrollTo(0, start + ((target - start) * i) / steps)
      await new Promise((r) => setTimeout(r, 40))
    }
  }, y)
  await page.waitForTimeout(1800)
  const name = `${out}/${String(Math.round(f * 1000)).padStart(4, '0')}.png`
  await page.screenshot({ path: name })
  console.log('shot', name, y)
}
console.log(errors.length ? errors.slice(0, 20).join('\n') : 'no console errors')
await browser.close()
