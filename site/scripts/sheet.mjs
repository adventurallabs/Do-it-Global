import { chromium } from 'playwright-core'
const [url, out, w = '1600', h = '2000'] = process.argv.slice(2)
const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true })
const page = await browser.newPage({ viewport: { width: +w, height: +h } })
const errs = []
page.on('pageerror', (e) => errs.push(e.message))
page.on('console', (m) => m.type() === 'error' && errs.push(m.text()))
await page.goto(url, { waitUntil: 'networkidle' })
await page.waitForTimeout(1500)
await page.screenshot({ path: out, fullPage: true })
console.log(errs.join('\n') || 'ok')
await browser.close()
