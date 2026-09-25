import { useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import { mdiBullhornOutline, mdiCalendarCheckOutline, mdiClipboardTextOutline, mdiSchoolOutline, mdiStar } from '@mdi/js'
import { gsap, ScrollTrigger } from '../../animations/gsap'
import { DeviceFrame } from '../../components/DeviceFrame'
import { Icon, SectionLabel } from '../../components/Primitives'
import { useSection } from '../../hooks/useSection'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { AttendanceScreen, BusScreen, FeesScreen, ProgressScreen } from '../../screens/connect/FeatureScreens'
import { NotificationsScreen } from '../../screens/connect/SchoolScreens'
import { RollCallScreen } from '../../screens/core/OpsScreens'
import { STOP_T } from '../../data/busRoute'
import { remap } from '../../lib/math'

/**
 * Scroll progress through a sticky feature, quantised so React only
 * re-renders the recreated screen when something visible changes.
 */
export function useScrub(ref: React.RefObject<HTMLElement | null>, steps: number, reduced: boolean, map: (p: number) => number = (p) => p) {
  const [v, setV] = useState(reduced ? steps : 0)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el || reduced) return
    const st = ScrollTrigger.create({
      trigger: el,
      start: 'top top',
      end: 'bottom bottom',
      onUpdate: (self) => setV(Math.round(map(self.progress) * steps)),
    })
    return () => st.kill()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reduced, steps])
  return v / steps
}

type LayoutProps = {
  id: string
  index: string
  label: string
  title: string
  text: string
  /** Shorter copy for phones, where the pinned stage has little height. */
  mobileText?: string
  facts?: string[]
  accent: string
  height?: number
  children: ReactNode
  sectionRef: (el: HTMLElement | null) => void
  reduced: boolean
  /** Keep the left column narrow and the visual large. */
  wideVisual?: boolean
}

export function FeatureLayout({ id, index, label, title, text, mobileText, facts, accent, height = 240, children, sectionRef, reduced, wideVisual }: LayoutProps) {
  return (
    <section ref={sectionRef} id={id} className="relative" style={{ height: reduced ? undefined : `${height}svh` }}>
      <div className={reduced ? 'py-24' : 'sticky-stage'}>
        <div className={`mx-auto grid h-full max-w-[1600px] items-center gap-6 px-5 pt-20 sm:px-8 md:px-12 lg:gap-16 lg:pt-0 ${wideVisual ? 'lg:grid-cols-[minmax(18rem,24rem)_1fr]' : 'lg:grid-cols-[minmax(20rem,28rem)_1fr]'}`}>
          <div data-copy className="order-2 lg:order-1">
            <SectionLabel index={index} accent={accent}>
              {label}
            </SectionLabel>
            <h3 className="t-h2 mt-5 text-bone lg:mt-7">{title}</h3>
            <p className="mt-4 max-w-[30rem] text-[0.98rem] leading-relaxed text-mute lg:mt-6 lg:text-[1.05rem]">
              {mobileText ? (
                <>
                  <span className="sm:hidden">{mobileText}</span>
                  <span className="hidden sm:inline">{text}</span>
                </>
              ) : (
                text
              )}
            </p>
            {facts && (
              <ul className="mt-6 hidden flex-col gap-2 lg:flex">
                {facts.map((f) => (
                  <li key={f} className="flex items-center gap-3 text-[0.9rem] text-bone/80">
                    <span className="h-1.5 w-1.5 rounded-full" style={{ background: accent }} />
                    {f}
                  </li>
                ))}
              </ul>
            )}
          </div>
          <div className="order-1 flex h-full max-h-[62svh] items-center justify-center lg:order-2 lg:max-h-none">{children}</div>
        </div>
      </div>
    </section>
  )
}

export function useFeature(id: string) {
  const sectionRef = useSection<HTMLElement>(id)
  const root = useRef<HTMLElement | null>(null)
  const set = (el: HTMLElement | null) => {
    root.current = el
    sectionRef(el)
  }
  return { root, set }
}

export const phoneBox = { width: 'min(19rem, 42vw)', height: 'min(66svh, 39rem, 100vw, calc(100svh - 21rem))' }

/* ---------------------------------------------------------------- */
/*  Attendance: a roll call becomes a parent's calendar               */
/* ---------------------------------------------------------------- */
export function AttendanceFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('attendance')
  const p = useScrub(root, 40, reduced)
  const marked = remap(p, 0.05, 0.4)
  const reveal = remap(p, 0.38, 0.9)
  return (
    <FeatureLayout
      id="features"
      index="05"
      label="Attendance"
      accent="#22C55E"
      title="A roll call becomes a parent’s calendar."
      text="The teacher marks the class in PalliCore. Parents see the day land on their child’s attendance calendar in PalliConnect, with the month summed up for them."
      facts={['Present, absent and leave, day by day', 'Monthly summary for every child', 'Leave requests from parents, reviewed by the school']}
      sectionRef={set}
      reduced={reduced}
      wideVisual
    >
      <div className="flex w-full items-center justify-center gap-3 sm:gap-8">
        <Captioned caption="PalliCore · Roll call" color="#E2C275">
          <DeviceFrame kind="phone" style={phoneBox} screenBg="#EDEBE7" label="PalliCore roll call">
            <RollCallScreen marked={marked} />
          </DeviceFrame>
        </Captioned>
        <FlowDots active={p > 0.3 && p < 0.95} />
        <Captioned caption="PalliConnect · Attendance" color="#3EC6FF">
          <DeviceFrame kind="phone" style={phoneBox} label="PalliConnect attendance calendar">
            <AttendanceScreen reveal={reveal} />
          </DeviceFrame>
        </Captioned>
      </div>
    </FeatureLayout>
  )
}

export function Captioned({ children, caption, color }: { children: ReactNode; caption: string; color: string }) {
  return (
    <div className="flex flex-col items-center gap-4">
      {children}
      <span className="t-label flex items-center gap-2 text-[0.6rem] sm:text-[0.66rem]">
        <span className="h-1.5 w-1.5 rounded-full" style={{ background: color }} />
        {caption}
      </span>
    </div>
  )
}

function FlowDots({ active }: { active: boolean }) {
  return (
    <div aria-hidden className={`hidden flex-col items-center gap-3 transition-opacity duration-700 sm:flex ${active ? 'opacity-100' : 'opacity-25'}`}>
      <div className="relative h-px w-16 overflow-hidden bg-gradient-to-r from-[#E2C275]/40 to-[#3EC6FF]/40 lg:w-24">
        <span className="flow-dot absolute top-1/2 h-1.5 w-6 -translate-y-1/2 rounded-full bg-gradient-to-r from-[#E2C275] to-[#3EC6FF]" />
      </div>
      <img src="/brand/palli-mark.webp" alt="" width={22} height={22} className="h-5 w-5 opacity-70" />
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  Academic progress: a journey that builds up over the year         */
/* ---------------------------------------------------------------- */
const TERMS = [
  { name: 'Unit tests', v: '82%', y: 0.72 },
  { name: 'Quarterly exams', v: '88.8%', y: 0.5 },
  { name: 'Half-yearly exams', v: 'Upcoming', y: 0.34 },
  { name: 'Annual exams', v: 'Upcoming', y: 0.2 },
]

export function ProgressFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('progress')
  const p = useScrub(root, 60, reduced)
  const draw = remap(p, 0.05, 0.75)
  const stars = Math.round(remap(p, 0.2, 0.7) * 24)
  return (
    <FeatureLayout
      id="progress-story"
      index="06"
      label="Academic progress"
      accent="#7FB2FF"
      title="Growth you can actually see."
      text="Exam results, homework consistency, stars from teachers and skills that move from Emerging to Advanced — a child’s year, building up in one place."
      facts={['Unit tests to annual exams', 'Stars with the reason they were given', 'Skills assessed by the school']}
      sectionRef={set}
      reduced={reduced}
      wideVisual
    >
      <div className="relative flex w-full items-center justify-center gap-10">
        <div className="relative hidden aspect-[4/5] w-full max-w-[26rem] xl:block">
          <svg viewBox="0 0 400 500" className="absolute inset-0 h-full w-full overflow-visible" aria-hidden>
            <defs>
              <linearGradient id="journey" x1="0" y1="1" x2="1" y2="0">
                <stop offset="0" stopColor="#2F6BFF" />
                <stop offset="0.6" stopColor="#3EC6FF" />
                <stop offset="1" stopColor="#B79BFF" />
              </linearGradient>
            </defs>
            <path d="M 30 470 C 90 440, 80 360, 150 330 S 230 230, 260 180 S 330 90, 380 70" fill="none" stroke="rgba(237,234,227,.08)" strokeWidth="2" strokeDasharray="4 6" />
            <path d="M 30 470 C 90 440, 80 360, 150 330 S 230 230, 260 180 S 330 90, 380 70" fill="none" stroke="url(#journey)" strokeWidth="3" strokeLinecap="round" pathLength={1} strokeDasharray="1" strokeDashoffset={1 - draw * 0.55} style={{ transition: 'stroke-dashoffset .3s' }} />
          </svg>
          {TERMS.map((t, i) => {
            const on = draw > i * 0.3
            const released = t.v !== 'Upcoming'
            return (
              <div key={t.name} className="absolute transition-all duration-700" style={{ left: `${10 + i * 24}%`, top: `${t.y * 100}%`, opacity: on ? 1 : 0.2, transform: `translateY(${on ? 0 : 12}px)` }}>
                <span className="block h-3 w-3 rounded-full border-2" style={{ borderColor: released ? '#3EC6FF' : 'rgba(237,234,227,.3)', background: released && on ? '#3EC6FF' : 'transparent', boxShadow: released && on ? '0 0 18px #3EC6FF' : undefined }} />
                <span className="mt-2 block whitespace-nowrap text-[0.8rem] text-bone/85">{t.name}</span>
                <span className="text-[0.95rem] font-medium" style={{ color: released ? '#fff' : 'rgba(237,234,227,.4)' }}>
                  {t.v}
                </span>
              </div>
            )
          })}
          <div className="glass absolute bottom-2 right-0 flex items-center gap-3 rounded-2xl px-4 py-3">
            <Icon path={mdiStar} size={22} color="#F5A524" />
            <span className="text-[1.4rem] font-semibold tabular-nums text-bone">{stars}</span>
            <span className="text-[0.8rem] text-mute">Stars earned</span>
          </div>
        </div>
        <DeviceFrame kind="phone" style={phoneBox} label="PalliConnect progress">
          <ProgressScreen grow={remap(p, 0.25, 0.75)} />
        </DeviceFrame>
      </div>
    </FeatureLayout>
  )
}

/* ---------------------------------------------------------------- */
/*  Communication: what the school sends, arriving on the phone       */
/* ---------------------------------------------------------------- */
const SENDS = [
  { icon: mdiClipboardTextOutline, who: 'Teacher', what: 'Assigns homework', detail: 'Mathematics — worksheet 4', lands: 0 },
  { icon: mdiSchoolOutline, who: 'Teacher', what: 'Publishes marks', detail: 'Quarterly exams', lands: 2 },
  { icon: mdiBullhornOutline, who: 'Admin', what: 'Posts an announcement', detail: 'Parent meeting · Saturday', lands: 3 },
  { icon: mdiCalendarCheckOutline, who: 'Admin', what: 'Composes an event', detail: 'Annual Day · registrations', lands: 5 },
]

export function CommunicationFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('communication')
  const p = useScrub(root, 40, reduced)
  const active = Math.min(SENDS.length - 1, Math.floor(remap(p, 0.1, 0.9) * SENDS.length))

  useLayoutEffect(() => {
    const el = root.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      const packets = gsap.utils.toArray<HTMLElement>('[data-packet]')
      const target = el.querySelector<HTMLElement>('[data-inbox]')
      const tl = gsap.timeline({ scrollTrigger: { trigger: el, start: 'top top', end: 'bottom bottom', scrub: 0.7, invalidateOnRefresh: true } })
      packets.forEach((pk, i) => {
        // Measured from the card (never transformed), so refreshes stay exact.
        const dx = () => {
          const card = pk.parentElement!.getBoundingClientRect()
          const inbox = target?.getBoundingClientRect()
          return inbox ? inbox.left + inbox.width / 2 - (card.right - 22) : 300
        }
        const at = 0.1 + i * 0.2
        tl.fromTo(pk, { x: 0, autoAlpha: 0, scale: 0.6 }, { x: dx, autoAlpha: 1, scale: 1, duration: 0.14, ease: 'power2.inOut' }, at)
        tl.to(pk, { autoAlpha: 0, scale: 0.4, duration: 0.04 }, at + 0.14)
      })
      tl.to({}, { duration: 0.1 }, 0.9)
    }, el)
    return () => ctx.revert()
  }, [reduced])

  return (
    <FeatureLayout
      id="communication"
      index="07"
      label="School communication"
      accent="#B79BFF"
      title="The school speaks once. Every family hears it."
      text="Homework, results, announcements, events and diary notes are written in PalliCore and arrive in PalliConnect as updates and notifications — no forwarded messages, no missed notes in a bag."
      sectionRef={set}
      reduced={reduced}
      wideVisual
    >
      <div className="flex w-full items-center justify-center gap-6 lg:gap-16">
        <div className="hidden w-full max-w-[20rem] flex-col gap-3 md:flex">
          <span className="t-label mb-1 flex items-center gap-2 text-[0.64rem]">
            <span className="h-1.5 w-1.5 rounded-full bg-[#E2C275]" />
            From PalliCore
          </span>
          {SENDS.map((s, i) => (
            <div key={s.what} className={`relative rounded-2xl border px-4 py-3 transition-all duration-500 ${i === active ? 'border-[#E2C275]/50 bg-white/[0.07]' : 'border-white/[0.08] bg-white/[0.03]'}`}>
              <span className="flex items-center gap-3">
                <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-[#E2C275]/12">
                  <Icon path={s.icon} size={18} color="#E2C275" />
                </span>
                <span>
                  <span className="block text-[0.88rem] text-bone">
                    {s.who} · {s.what}
                  </span>
                  <span className="block text-[0.76rem] text-mute">{s.detail}</span>
                </span>
              </span>
              <span data-packet aria-hidden className="absolute right-3 top-1/2 z-20 h-2.5 w-2.5 -translate-y-1/2 rounded-full bg-[#d9c8ff] opacity-0 shadow-[0_0_18px_6px_rgba(183,155,255,.55)]" />
            </div>
          ))}
        </div>
        <div data-inbox>
          <DeviceFrame kind="phone" style={phoneBox} label="PalliConnect notifications">
            <NotificationsScreen highlight={p > 0.08 ? SENDS[active].lands : -1} />
          </DeviceFrame>
        </div>
      </div>
    </FeatureLayout>
  )
}

/* ---------------------------------------------------------------- */
/*  Fees                                                              */
/* ---------------------------------------------------------------- */
export function FeesFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('fees')
  const p = useScrub(root, 20, reduced)
  const paid = p > 0.55
  return (
    <FeatureLayout
      id="fees"
      index="08"
      label="Fees"
      accent="#3EC6FF"
      title="What’s due, what’s paid, and the receipt."
      text="Parents see the year’s fees broken down — tuition, transport, activities — and pay from the app. The school sees payments, online or at the counter, in Fee management."
      facts={['Category-wise breakdown', 'Pay Now from the Fee due screen', 'Payment history with receipts']}
      sectionRef={set}
      reduced={reduced}
    >
      <div className="relative flex items-center justify-center">
        <DeviceFrame kind="phone" style={phoneBox} label="PalliConnect fees">
          <FeesScreen paid={paid} />
        </DeviceFrame>
        <div className={`glass absolute -right-4 top-[18%] hidden w-[15rem] rounded-2xl px-4 py-3.5 transition-all duration-700 sm:block lg:-right-52 ${paid ? 'translate-y-0 opacity-100' : 'translate-y-4 opacity-0'}`}>
          <span className="flex items-center gap-2 text-[0.9rem] text-bone">
            <span className="h-2 w-2 rounded-full bg-[#22C55E] shadow-[0_0_12px_#22C55E]" />
            Payment successful
          </span>
          <span className="mt-1 block pl-4 text-[0.78rem] text-mute">₹12,000 · Receipt RCPT-1107</span>
        </div>
        <div className={`glass absolute -left-4 bottom-[16%] hidden w-[15rem] rounded-2xl px-4 py-3.5 transition-all delay-200 duration-700 sm:block lg:-left-56 ${paid ? 'translate-y-0 opacity-100' : 'translate-y-4 opacity-0'}`}>
          <span className="flex items-center gap-2 text-[0.9rem] text-bone">
            <span className="h-2 w-2 rounded-full bg-[#E2C275] shadow-[0_0_12px_#E2C275]" />
            PalliCore · Fee management
          </span>
          <span className="mt-1 block pl-4 text-[0.78rem] text-mute">Class 5 fees · 84% → 87% paid</span>
        </div>
      </div>
    </FeatureLayout>
  )
}

/* ---------------------------------------------------------------- */
/*  Real-time bus tracking (the 3D route lives in the canvas)         */
/* ---------------------------------------------------------------- */
function stopIndexAt(t: number) {
  let idx = 0
  for (let i = 0; i < STOP_T.length; i++) if (t >= STOP_T[i] - 0.03) idx = i
  return idx
}

export function BusFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('bus')
  const t = useScrub(root, 100, reduced, (p) => remap(p, 0.08, 0.88))
  const at = reduced ? 3 : stopIndexAt(t)
  return (
    <section ref={set} id="bus" className="relative" style={{ height: reduced ? undefined : '300svh' }}>
      <div className={reduced ? 'py-24' : 'sticky-stage'}>
        <div className="mx-auto flex h-full max-w-[1600px] flex-col justify-between px-5 pb-8 pt-20 sm:px-8 md:px-12 lg:flex-row lg:items-center lg:pb-0 lg:pt-0">
          <div className="max-w-[26rem]">
            <SectionLabel index="09" accent="#22C55E">
              Real-time bus tracking
            </SectionLabel>
            <h3 className="t-h2 mt-5 text-bone lg:mt-7">Every stop, as it happens.</h3>
            <p className="mt-4 hidden text-[1.02rem] leading-relaxed text-mute sm:block lg:mt-6">
              Parents follow the school bus stop by stop and see how many stops are left before theirs. The school sees the whole fleet live in PalliCore.
            </p>
            <div className="mt-6 hidden gap-6 lg:flex">
              <Stat v={`${Math.max(0, 5 - at)}`} l="stops before yours" />
              <Stat v={at >= 5 ? '8' : '32'} l="km/h · LIVE" />
            </div>
          </div>
          <div className="flex justify-center lg:justify-end">
            <DeviceFrame kind="phone" style={{ width: 'min(20rem, 58vw)', height: 'min(74svh, 41rem, calc(100svh - 12rem))' }} label="PalliConnect bus tracking">
              <BusScreen at={at} />
            </DeviceFrame>
          </div>
        </div>
      </div>
    </section>
  )
}

function Stat({ v, l }: { v: string; l: string }) {
  return (
    <div>
      <span className="block text-[2.2rem] font-medium tabular-nums tracking-[-0.04em] text-bone">{v}</span>
      <span className="t-label text-[0.62rem]">{l}</span>
    </div>
  )
}
