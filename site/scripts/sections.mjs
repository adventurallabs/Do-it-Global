// Dev-only: screenshots named sections at points through their scroll.
// Usage: node scripts/sections.mjs <url> <w>x<h> <outDir> <id:f,f,f> ... [--mobile]
import { chromium } from 'playwright-core'
import { mkdirSync } from 'node:fs'
const [url, size, out, ...rest] = process.argv.slice(2)
const mobile = rest.includes('--mobile')
const specs = rest.filter((r) => !r.startsWith('--'))
const [w, h] = size.split('x').map(Number)
mkdirSync(out, { recursive: true })
const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist'], headless: true })
const page = await browser.newPage({ viewport: { width: w, height: h }, isMobile: mobile, hasTouch: mobile, deviceScaleFactor: 1 })
const errors = []
page.on('pageerror', (e) => errors.push(e.message))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))
await page.goto(url, { waitUntil: 'networkidle' })
await page.waitForTimeout(2500)
for (const spec of specs) {
  const [id, fr] = spec.split(':')
  for (const f of fr.split(',').map(Number)) {
    const y = await page.evaluate(([id, f]) => {
      const el = document.getElementById(id)
      const top = el.getBoundingClientRect().top + scrollY
      return Math.round(top + Math.max(0, el.offsetHeight - innerHeight) * f)
    }, [id, f])
    await page.evaluate(async (t) => { const s = scrollY; for (let i = 1; i <= 8; i++) { scrollTo(0, s + ((t - s) * i) / 8); await new Promise((r) => setTimeout(r, 30)) } }, y)
    await page.waitForTimeout(1600)
    await page.screenshot({ path: `${out}/${id}-${f}.png` })
  }
}
console.log(errors.length ? errors.join('\n') : 'no errors')
await browser.close()
