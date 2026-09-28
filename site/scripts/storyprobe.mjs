// Dev-only: wheels through every pinned DeviceStory down and back up and
// checks that some app screen always covers the device (no blank screen).
// Usage: node scripts/storyprobe.mjs <url> <w>x<h> [--mobile] [--delta n] [--wait ms]
import { chromium } from 'playwright-core'

const args = process.argv.slice(2)
const url = args[0]
const [w, h] = (args[1] ?? '1440x900').split('x').map(Number)
const mobile = args.includes('--mobile')
const delta = args.includes('--delta') ? Number(args[args.indexOf('--delta') + 1]) : 120
const wait = args.includes('--wait') ? Number(args[args.indexOf('--wait') + 1]) : 40

const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true })
const page = await browser.newPage({ viewport: { width: w, height: h }, isMobile: mobile, hasTouch: mobile })
await page.goto(url, { waitUntil: 'networkidle' })
await page.waitForTimeout(2000)

const check = () =>
  page.evaluate(() => {
    const out = []
    for (const sec of document.querySelectorAll('section')) {
      const screens = [...sec.querySelectorAll('[data-screen]')]
      if (!screens.length) continue
      const r = sec.getBoundingClientRect()
      // Only while the stage is pinned and the device is on screen.
      if (r.top > 0 || r.bottom < innerHeight) continue
      const holder = screens[0].parentElement.getBoundingClientRect()
      const dev = sec.querySelector('.device-3d')
      if (!dev || +getComputedStyle(dev).opacity < 0.99) continue
      let cover = 0
      const vis = []
      const spans = []
      screens.forEach((s, i) => {
        const cs = getComputedStyle(s)
        if (cs.visibility === 'hidden' || +cs.opacity < 0.05) return
        const b = s.getBoundingClientRect()
        const ow = Math.max(0, Math.min(b.right, holder.right) - Math.max(b.left, holder.left))
        const oh = Math.max(0, Math.min(b.bottom, holder.bottom) - Math.max(b.top, holder.top))
        const f = ((ow * oh) / (holder.width * holder.height)) * +cs.opacity
        cover = Math.max(cover, f)
        if (+cs.opacity > 0.95 && oh / holder.height > 0.97) spans.push([Math.max(b.left, holder.left), Math.min(b.right, holder.right)])
        vis.push(`${i}:${f.toFixed(2)}`)
      })
      // Screens sliding side by side (a push) cover the device together.
      spans.sort((x, y) => x[0] - y[0])
      let reach = holder.left
      for (const [l, r] of spans) if (l <= reach + 1) reach = Math.max(reach, r)
      cover = Math.max(cover, (reach - holder.left) / holder.width)
      out.push({ id: sec.id, top: Math.round(-r.top), cover, vis: vis.join(' ') })
    }
    return out
  })

await page.mouse.move(w / 2, h / 2)
const bad = []
const run = async (dir) => {
  let last = -1, same = 0
  for (let i = 0; i < 4000; i++) {
    await page.mouse.wheel(0, dir * delta)
    await page.waitForTimeout(wait)
    const y = await page.evaluate(() => scrollY)
    same = y === last ? same + 1 : 0
    last = y
    if (same > 15) break
    for (const c of await check()) if (c.cover < 0.9) bad.push(`${dir > 0 ? 'DOWN' : 'UP  '} y=${y} ${c.id}@${c.top} cover=${c.cover.toFixed(2)} [${c.vis}]`)
  }
}
await run(1)
await page.waitForTimeout(1500)
await run(-1)
if (args.includes('--jitter')) {
  // Random direction changes and instant jumps, like a restless thumb or a nav link.
  const total = await page.evaluate(() => document.documentElement.scrollHeight - innerHeight)
  for (let i = 0; i < 600; i++) {
    if (i % 60 === 0) await page.evaluate((y) => scrollTo(0, y), Math.random() * total)
    else await page.mouse.wheel(0, (Math.random() < 0.5 ? -1 : 1) * delta * (0.3 + Math.random() * 2))
    await page.waitForTimeout(wait)
    for (const c of await check()) if (c.cover < 0.9) bad.push(`JIT  ${c.id}@${c.top} cover=${c.cover.toFixed(2)} [${c.vis}]`)
  }
  await page.waitForTimeout(1500)
  for (const c of await check()) if (c.cover < 0.99) bad.push(`SETTLED ${c.id}@${c.top} cover=${c.cover.toFixed(2)} [${c.vis}]`)
}
console.log(bad.length ? `BLANK FRAMES (${bad.length}):\n` + bad.slice(0, 60).join('\n') : 'no blank device frames')
await browser.close()
