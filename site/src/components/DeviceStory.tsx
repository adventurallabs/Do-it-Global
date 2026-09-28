import { useLayoutEffect, useRef, type ReactNode } from 'react'
import { gsap, ScrollTrigger } from '../animations/gsap'
import { DeviceFrame } from './DeviceFrame'
import { useSection } from '../hooks/useSection'
import { useReducedMotion } from '../hooks/useReducedMotion'
import { useIsDesktop, useMediaQuery } from '../hooks/useMediaQuery'
import { quality } from '../lib/quality'
import { registerStops, timelineStops } from '../lib/tapStops'

export type StoryStep = {
  label: string
  title: string
  text: string
  screen: ReactNode
  /** 'push' slides in like a pushed route; 'tab' fades through like a tab switch. */
  transition?: 'push' | 'tab'
  /** A piece of UI lifted out of the device into space. */
  float?: { text: string; sub?: string; color: string; pos: 'tl' | 'tr' | 'bl' | 'br' }
}

type Props = {
  id: string
  kind: 'phone' | 'tablet'
  accent: string
  icon: string
  name: string
  subtitle: string
  lead: string
  audience: string
  steps: StoryStep[]
  screenBg: string
}

/** Device pose per step: the "camera" drifts around the device as you scroll. */
const POSES = [
  { ry: -14, rx: 6, s: 1, x: 0 },
  { ry: 9, rx: 3, s: 1.02, x: 0 },
  { ry: -6, rx: -2, s: 1.06, x: -1 },
  { ry: 12, rx: 4, s: 1, x: 1 },
  { ry: -10, rx: -3, s: 1.04, x: 0 },
  { ry: 6, rx: 5, s: 1.08, x: -1 },
  { ry: -12, rx: 2, s: 1, x: 1 },
  { ry: 8, rx: -2, s: 1.03, x: 0 },
  { ry: -5, rx: 3, s: 1.05, x: 0 },
]

/**
 * A pinned chapter that walks through an app one screen at a time. The
 * device enters, turns and leans as the scroll advances; screens push and
 * fade like they do in the real app; captions follow along.
 */
export function DeviceStory(p: Props) {
  const reduced = useReducedMotion()
  const desktop = useIsDesktop()
  const tabletUp = useMediaQuery('(min-width: 640px)')
  const sectionRef = useSection<HTMLElement>(p.id)
  const root = useRef<HTMLElement | null>(null)
  const kind = desktop ? p.kind : 'phone'

  useLayoutEffect(() => {
    const el = root.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      const device = el.querySelector<HTMLElement>('.device-3d')!
      const screens = gsap.utils.toArray<HTMLElement>('[data-screen]', el)
      const texts = gsap.utils.toArray<HTMLElement>('[data-step-text]', el)
      const floats = gsap.utils.toArray<HTMLElement>('[data-float]', el)
      const labels = gsap.utils.toArray<HTMLElement>('[data-step-label]', el)
      const bar = el.querySelector<HTMLElement>('[data-progress]')
      const counter = el.querySelector<HTMLElement>('[data-counter]')
      const n = p.steps.length
      const INTRO = 1.3
      const mob = !desktop
      // Touch devices: no 3D. Rotating a clipped, rounded screen in 3D makes
      // phones re-raster it every scroll frame (it shows white while the
      // tiles catch up) and trips WebKit's 3D clipping bugs. There the device
      // only rises and fades; screens still push and cross-fade.
      const flat = quality.coarse

      gsap.set(texts.slice(1), { autoAlpha: 0, y: 30 })
      if (floats.length) gsap.set(floats, { autoAlpha: 0, scale: 0.85, z: 0 })

      // Screens are not tweened. Their state is a pure function of the
      // timeline's playhead, rewritten every update: scrolling up, down, fast
      // or mid-transition always lands on exactly the right screen, with none
      // of the stale start values a reversed chain of tweens can leave behind.
      // Transforms stay 2D so screens never get their own GPU layers — on
      // phones, layers promoted and dropped per transition exhausted GPU
      // memory and a screen coming back on scroll-up stayed blank (white).
      // Hidden screens use plain `visibility`, never `content-visibility`:
      // un-skipping a subtree on the frame it is needed is exactly when a
      // phone falls behind, and WebKit could leave it unpainted.
      const shades = screens.map((s) => s.querySelector<HTMLElement>('[data-shade]'))
      const starts = p.steps.map((_, i) => INTRO + i - 0.5)
      const pushEase = gsap.parseEase('power3.inOut')
      const tabEase = gsap.parseEase('power2.out')
      const written: string[] = []
      let activeLabel = -1
      let active = 0
      let healed = false

      const paint = (i: number, key: string, vis: string, transform: string, opacity: string, shade: string) => {
        if (written[i] === key) return
        written[i] = key
        const st = screens[i].style
        st.visibility = vis
        st.transform = transform
        st.opacity = opacity
        if (shades[i]) shades[i]!.style.opacity = shade
      }

      const render = (t: number) => {
        let a = 0
        for (let i = 1; i < n; i++) if (t >= starts[i]) a = i
        const push = (p.steps[a].transition ?? 'push') === 'push'
        const q = a === 0 ? 1 : Math.min(1, (t - starts[a]) / (push ? 0.46 : 0.36))
        const e = push ? pushEase(q) : tabEase(q)
        active = a
        for (let i = 0; i < n; i++) {
          if (i === a && q >= 1) paint(i, 'on', 'visible', 'none', '1', '0')
          else if (i === a && push) paint(i, `in${e}`, 'visible', `translate(${((1 - e) * 100).toFixed(3)}%,0)`, '1', '0')
          else if (i === a) paint(i, `in${e}`, 'visible', `translate(0,${((1 - e) * 2).toFixed(3)}%)`, e.toFixed(4), '0')
          else if (i === a - 1 && q < 1)
            paint(i, `out${e}`, 'visible', push ? `translate(${(-28 * e).toFixed(3)}%,0)` : 'none', '1', push ? (0.2 * e).toFixed(4) : '0')
          else paint(i, 'off', 'hidden', 'none', '1', '0')
        }
        const idx = Math.max(0, Math.min(n - 1, Math.floor(t - INTRO + 0.5)))
        if (idx !== activeLabel) {
          activeLabel = idx
          labels.forEach((l, i) => (l.dataset.active = i === idx ? '1' : i < idx ? 'past' : ''))
          if (counter) counter.textContent = `${String(idx + 1).padStart(2, '0')} / ${String(n).padStart(2, '0')}`
        }
      }

      // Safety net for real phones: when the scroll comes to rest (or the tab
      // returns from the background, where mobile browsers drop GPU tiles),
      // rewrite every screen and invalidate the visible one's paint, so a
      // tile the GPU evicted mid-scroll is re-rastered instead of staying
      // white. The shade alternates between two invisible values (render
      // just wrote 0, so each heal is a real change) purely to trigger that
      // repaint.
      const heal = () => {
        written.length = 0
        render(tl.time())
        healed = !healed
        const shade = shades[active]
        if (shade && written[active] === 'on') shade.style.opacity = healed ? '0.001' : '0.002'
      }
      const onVisible = () => document.visibilityState === 'visible' && heal()

      // force3D off: GSAP otherwise swaps captions to translate3d while they
      // tween and back afterwards — a GPU layer created and dropped on every
      // step, which is the churn that starves a phone's raster budget.
      const tl = gsap.timeline({
        defaults: { ease: 'power2.inOut', force3D: false },
        onUpdate: () => render(tl.time()),
        scrollTrigger: {
          trigger: el,
          start: 'top top',
          end: 'bottom bottom',
          scrub: 0.9,
          onScrubComplete: heal,
          // May fire while the timeline is still being built, before `tl` exists.
          onRefresh: (self) => self.animation && render(self.animation.time()),
        },
      })

      // The device holds a GPU layer only while its story is on screen, so
      // the two stories never pin layer memory for each other.
      device.style.willChange = 'auto'
      ScrollTrigger.create({
        trigger: el,
        start: 'top bottom',
        end: 'bottom top',
        onToggle: (self) => (device.style.willChange = self.isActive ? 'transform' : 'auto'),
      })
      document.addEventListener('visibilitychange', onVisible)
      window.addEventListener('pageshow', heal)

      // Intro: the name owns the screen, then hands over to the device.
      if (flat) tl.fromTo(device, { yPercent: 30, autoAlpha: 0 }, { yPercent: 0, autoAlpha: 1, duration: 0.85, ease: 'power3.out' }, 0.4)
      else
        tl.fromTo(
          device,
          { yPercent: mob ? 30 : 55, rotateX: 34, rotateY: -24, scale: 0.86, autoAlpha: 0 },
          { yPercent: 0, rotateX: POSES[0].rx, rotateY: mob ? POSES[0].ry * 0.4 : POSES[0].ry, scale: 1, autoAlpha: 1, duration: 0.85, ease: 'power3.out' },
          0.4,
        )
      tl.to('[data-intro]', { autoAlpha: 0, y: -60, duration: 0.4, ease: 'power2.in' }, 0.3)
      tl.fromTo('[data-rail]', { autoAlpha: 0, y: 40 }, { autoAlpha: 1, y: 0, duration: 0.4, ease: 'power3.out' }, 0.95)
      if (bar) tl.fromTo(bar, { scaleY: 0 }, { scaleY: 1, duration: n - 1 + 0.3, ease: 'none' }, INTRO)
      if (!flat) tl.fromTo(device, { '--glare': 0.15 }, { '--glare': 0.85, duration: n + INTRO, ease: 'none' }, 0)

      for (let i = 1; i < n; i++) {
        const at = starts[i]
        tl.to(texts[i - 1], { autoAlpha: 0, y: -24, duration: 0.25, ease: 'power2.in' }, at - 0.05)
        tl.fromTo(texts[i], { autoAlpha: 0, y: 30 }, { autoAlpha: 1, y: 0, duration: 0.35, ease: 'power3.out', immediateRender: false }, at + 0.2)
        const pose = POSES[i % POSES.length]
        if (!flat)
          tl.to(
          device,
          { rotateY: mob ? pose.ry * 0.4 : pose.ry, rotateX: pose.rx, scale: mob ? 1 : pose.s, xPercent: mob ? 0 : pose.x * 4, duration: 0.9, ease: 'power2.inOut' },
          at - 0.2,
        )
      }
      floats.forEach((f) => {
        const i = Number(f.dataset.float)
        const at = INTRO + i - 0.5 + 0.35
        tl.fromTo(f, { autoAlpha: 0, scale: 0.8, z: 0 }, { autoAlpha: 1, scale: 1, z: 90, duration: 0.3, ease: 'power3.out', immediateRender: false }, i === 0 ? INTRO - 0.2 : at)
        tl.to(f, { autoAlpha: 0, z: 160, duration: 0.25, ease: 'power2.in' }, INTRO + i + 0.35)
      })
      tl.call(() => {}, [], '+=0.35') // hold on the last screen
      // Tap stops: the title, then each step once its screen, caption and
      // float have all settled (floats leave at +0.35).
      const unstop = registerStops(el, timelineStops(tl, [0, ...p.steps.map((_, i) => INTRO + i + 0.15)]))
      render(tl.time())

      return () => {
        unstop()
        document.removeEventListener('visibilitychange', onVisible)
        window.removeEventListener('pageshow', heal)
        device.style.removeProperty('will-change')
        screens.forEach((s, i) => {
          s.style.removeProperty('visibility')
          s.style.removeProperty('transform')
          s.style.removeProperty('opacity')
          shades[i]?.style.removeProperty('opacity')
        })
      }
    }, el)
    return () => ctx.revert()
  }, [reduced, desktop, p.steps])

  const setRefs = (el: HTMLElement | null) => {
    root.current = el
    sectionRef(el)
  }

  if (reduced) return <StaticStory {...p} setRef={setRefs} />

  const n = p.steps.length
  return (
    <section ref={setRefs} id={p.id} className="relative" style={{ height: `${n * 78 + 180}svh` }} aria-label={`${p.name} — ${p.subtitle}`}>
      <div className="sticky-stage">
        {/* Intro title */}
        <div data-intro className="pointer-events-none absolute inset-x-0 top-[12svh] z-20 mx-auto max-w-[1600px] px-5 sm:px-8 md:px-12 lg:top-1/2 lg:-translate-y-1/2">
          <div className="flex items-center gap-3">
            <img src={p.icon} alt="" width={44} height={44} className="h-11 w-11 rounded-[12px]" />
            <span className="t-label" style={{ color: p.accent }}>
              {p.audience}
            </span>
          </div>
          <h2 className="t-display mt-6 text-bone">{p.name}</h2>
          <p className="t-h3 mt-5 max-w-[22ch] text-bone/85">{p.subtitle}</p>
          <p className="t-lead mt-5 hidden max-w-[34rem] lg:block">{p.lead}</p>
        </div>

        <div className="mx-auto grid h-full max-w-[1600px] grid-rows-[1fr_auto] px-5 sm:px-8 md:px-12 lg:grid-cols-[minmax(20rem,26rem)_1fr] lg:grid-rows-1 lg:gap-10">
          {/* Caption rail */}
          <div data-rail className="relative order-2 pb-8 lg:order-1 lg:flex lg:flex-col lg:justify-center lg:pb-0">
            <div className="hidden items-center gap-3 lg:flex">
              <img src={p.icon} alt="" width={28} height={28} className="h-7 w-7 rounded-[8px]" />
              <span className="text-[0.95rem] font-medium text-bone">{p.name}</span>
              <span data-counter className="t-label ml-auto">
                01 / {String(n).padStart(2, '0')}
              </span>
            </div>
            <div className="relative mt-2 min-h-[8.5rem] lg:mt-10 lg:min-h-[13rem]">
              {p.steps.map((s, i) => (
                <div key={s.label} data-step-text className="absolute inset-x-0 top-0">
                  <p className="t-label mb-3 lg:mb-4" style={{ color: p.accent }}>
                    {s.label}
                  </p>
                  <h3 className="text-[1.55rem] font-medium leading-[1.08] tracking-[-0.03em] text-bone lg:text-[2.3rem]">{s.title}</h3>
                  <p className="mt-3 max-w-[26rem] text-[0.95rem] leading-relaxed text-mute lg:mt-4 lg:text-[1.02rem]">{s.text}</p>
                  <span className="sr-only">Step {i + 1}</span>
                </div>
              ))}
            </div>
            <div className="mt-8 hidden gap-5 lg:flex">
              <span className="relative block w-px bg-bone/10">
                <span data-progress className="absolute inset-0 origin-top" style={{ background: p.accent }} />
              </span>
              <ol className="flex flex-col gap-2.5">
                {p.steps.map((s) => (
                  <li key={s.label} data-step-label className="story-label text-[0.8rem] tracking-[-0.005em]">
                    {s.label}
                  </li>
                ))}
              </ol>
            </div>
          </div>

          {/* Device */}
          <div className="relative order-1 flex items-center justify-center pt-16 lg:order-2 lg:pt-0" style={quality.coarse ? undefined : { perspective: '2000px' }}>
            <div className="relative" style={quality.coarse ? undefined : { transformStyle: 'preserve-3d' }}>
              <DeviceFrame
                kind={kind}
                screenBg={p.screenBg}
                label={`${p.name} app screens`}
                style={kind === 'phone' ? { width: 'min(24rem, 78vw)', height: desktop ? '82svh' : tabletUp ? '60svh' : 'min(52svh, calc(100svh - 22rem))' } : { width: 'min(62vw, 1040px)', height: '78svh' }}
              >
                {p.steps.map((s, i) => (
                  <div key={s.label} data-screen className="absolute inset-0 overflow-hidden" style={{ zIndex: i, contain: 'layout paint' }}>
                    {s.screen}
                    {/* Dims the outgoing screen during a push (cheaper than a CSS filter). */}
                    <div data-shade aria-hidden className="pointer-events-none absolute inset-0 z-[100] bg-black opacity-0" />
                  </div>
                ))}
              </DeviceFrame>
              {desktop &&
                p.steps.map((s, i) =>
                  s.float ? (
                    <div
                      key={i}
                      data-float={i}
                      className={`glass pointer-events-none absolute z-30 max-w-[17rem] rounded-2xl px-4 py-3 ${floatPos[s.float.pos]}`}
                    >
                      <span className="flex items-center gap-2 text-[0.9rem] font-medium text-bone">
                        <span className="h-2 w-2 shrink-0 rounded-full" style={{ background: s.float.color, boxShadow: `0 0 12px ${s.float.color}` }} />
                        {s.float.text}
                      </span>
                      {s.float.sub && <span className="mt-1 block pl-4 text-[0.78rem] text-mute">{s.float.sub}</span>}
                    </div>
                  ) : null,
                )}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

const floatPos = {
  tl: '-left-40 top-[14%]',
  tr: '-right-40 top-[12%]',
  bl: '-left-44 bottom-[16%]',
  br: '-right-44 bottom-[14%]',
}

function StaticStory(p: Props & { setRef: (el: HTMLElement | null) => void }) {
  return (
    <section ref={p.setRef} id={p.id} className="relative px-5 py-32 sm:px-8 md:px-12">
      <div className="mx-auto max-w-[1600px]">
        <div className="flex items-center gap-3">
          <img src={p.icon} alt="" width={44} height={44} className="h-11 w-11 rounded-[12px]" />
          <span className="t-label" style={{ color: p.accent }}>
            {p.audience}
          </span>
        </div>
        <h2 className="t-display mt-6 text-bone">{p.name}</h2>
        <p className="t-h3 mt-5 max-w-[22ch] text-bone/85">{p.subtitle}</p>
        <p className="t-lead mt-5 max-w-[34rem]">{p.lead}</p>
        <div className="mt-20 grid gap-20 md:grid-cols-2">
          {p.steps.map((s) => (
            <div key={s.label}>
              <DeviceFrame kind={p.kind === 'tablet' ? 'tablet' : 'phone'} screenBg={p.screenBg} style={{ width: '100%', height: p.kind === 'tablet' ? 360 : 560 }} label={`${p.name}: ${s.label}`}>
                <div className="absolute inset-0">{s.screen}</div>
              </DeviceFrame>
              <p className="t-label mt-8" style={{ color: p.accent }}>
                {s.label}
              </p>
              <h3 className="mt-3 text-[1.6rem] font-medium tracking-[-0.03em] text-bone">{s.title}</h3>
              <p className="mt-3 max-w-[28rem] text-mute">{s.text}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
