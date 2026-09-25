import { chromium } from 'playwright-core'
const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true })
const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true })
await page.addInitScript(() => { const w = console.warn; console.warn = (...a) => { if (String(a[0]).includes('GSAP')) w('STACK', new Error().stack.split('\n').slice(2, 7).join(' | ')); w(...a) } })
page.on('console', (m) => m.text().startsWith('STACK') && console.log(m.text()))
await page.goto(process.argv[2], { waitUntil: 'networkidle' })
await page.waitForTimeout(2500)
await browser.close()
