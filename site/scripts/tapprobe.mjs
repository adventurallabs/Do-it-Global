// Dev-only: taps the right half of the page until the end, then the left half
// back to the top, checking that every tap moves one stop in the right
// direction and that app screens are never blank at a stop. Also checks that
// tapping a link/button does not step the page.
// Usage: node scripts/tapprobe.mjs <url> <w>x<h> [--mobile] [--out dir]
import { chromium } from 'playwright-core'
import { mkdirSync, writeFileSync } from 'node:fs'
import { PNG } from './png.mjs'

const args = process.argv.slice(2)
const url = args[0]
const [w, h] = (args[1] ?? '1440x900').split('x').map(Number)
const mobile = args.includes('--mobile')
const out = args.includes('--out') ? args[args.indexOf('--out') + 1] : null
if (out) mkdirSync(out, { recursive: true })

const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true })
const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: mobile ? 2 : 1, isMobile: mobile, hasTouch: mobile })
const errors = []
page.on('pageerror', (e) => errors.push(e.message))
await page.goto(url, { waitUntil: 'networkidle' })
await page.waitForTimeout(2500)

const tap = async (x, y) => (mobile ? page.touchscreen.tap(x, y) : page.mouse.click(x, y))
// A point on the page that isn't a link or button.
const emptyPoint = (side) =>
  page.evaluate((side) => {
    const xs = side > 0 ? [0.93, 0.85, 0.75, 0.62] : [0.07, 0.15, 0.25, 0.38]
    for (const fy of [0.5, 0.35, 0.65, 0.2, 0.8])
      for (const fx of xs) {
        const x = innerWidth * fx, y = innerHeight * fy
        const el = document.elementFromPoint(x, y)
        if (el && !el.closest('a, button, header, [role="button"]')) return { x, y }
      }
    return null
  }, side)

const problems = []
const blankScreen = async () => {
  const r = await page.evaluate(() => {
    for (const sec of document.querySelectorAll('section')) {
      const s = sec.querySelector('[data-screen]')
      if (!s || !sec.querySelector('.sticky-stage')) continue
      const r = sec.getBoundingClientRect()
      if (r.top > 0 || r.bottom < innerHeight) continue
      if (+getComputedStyle(sec.querySelector('.device-3d')).opacity < 0.99) continue
      const b = s.parentElement.getBoundingClientRect()
      return { x: b.left + b.width * 0.12, y: b.top + b.height * 0.12, width: b.width * 0.76, height: b.height * 0.76 }
    }
    return null
  })
  if (!r) return false
  return PNG.lumaStats(await page.screenshot({ clip: r, scale: 'css' })).sd < 6
}

const walk = async (dir) => {
  const ys = [await page.evaluate(() => scrollY)]
  for (let i = 0; i < 200; i++) {
    const pt = await emptyPoint(dir)
    if (!pt) {
      problems.push(`no empty spot to tap at y=${ys.at(-1)}`)
      break
    }
    await tap(pt.x, pt.y)
    await page.waitForTimeout(2200)
    const y = await page.evaluate(() => scrollY)
    if (y === ys.at(-1)) break
    if ((y - ys.at(-1)) * dir < 0) problems.push(`tap ${dir > 0 ? 'right' : 'left'} moved the wrong way: ${ys.at(-1)} -> ${y}`)
    ys.push(y)
    if (await blankScreen()) problems.push(`blank app screen at y=${y}`)
    if (out) writeFileSync(`${out}/${dir > 0 ? 'f' : 'b'}${String(ys.length).padStart(3, '0')}.png`, await page.screenshot({ scale: 'css' }))
  }
  return ys
}

const fwd = await walk(1)
const max = await page.evaluate(() => document.documentElement.scrollHeight - innerHeight)
console.log(`right taps: ${fwd.length - 1} steps, ended at ${fwd.at(-1)} of ${max}`)
if (Math.abs(fwd.at(-1) - max) > 4) problems.push('right taps did not reach the end of the page')
const back = await walk(-1)
console.log(`left taps: ${back.length - 1} steps, ended at ${back.at(-1)}`)
if (back.at(-1) > 4) problems.push('left taps did not reach the top')

// Tapping a real link/button must not also step the page.
await page.evaluate(() => scrollTo(0, 0))
await page.waitForTimeout(800)
const cta = await page.evaluate(() => {
  const a = [...document.querySelectorAll('main a, main button')].find((e) => { const r = e.getBoundingClientRect(); return r.top > 60 && r.bottom < innerHeight && r.width > 0 && !e.getAttribute('href')?.startsWith('#') })
  if (!a) return null
  const r = a.getBoundingClientRect()
  a.addEventListener('click', (e) => e.preventDefault(), { once: true })
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 }
})
if (cta) {
  await tap(cta.x, cta.y)
  await page.waitForTimeout(1500)
  if ((await page.evaluate(() => scrollY)) !== 0) problems.push('tapping a link stepped the page')
}
console.log(problems.length ? 'PROBLEMS:\n' + problems.join('\n') : 'tap navigation OK')
if (errors.length) console.log('page errors:\n' + errors.join('\n'))
await browser.close()
