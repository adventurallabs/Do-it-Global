import { useLayoutEffect, useRef } from 'react'
import { gsap } from '../../animations/gsap'
import { RevealText } from '../../components/RevealText'
import { SectionLabel, ScrollCue } from '../../components/Primitives'
import { MagneticButton, Arrow } from '../../components/MagneticButton'
import { useSection } from '../../hooks/useSection'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { SITE } from '../../data/site'

/* ---------------------------------------------------------------- */
/*  Hero                                                              */
/* ---------------------------------------------------------------- */
export function PalliHero() {
  const ref = useSection<HTMLElement>('hero')
  const inner = useRef<HTMLDivElement>(null)
  const reduced = useReducedMotion()

  useLayoutEffect(() => {
    const el = inner.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      gsap.from('[data-fade]', { opacity: 0, y: 26, duration: 1.8, stagger: 0.12, delay: 0.8 })
      gsap.from('[data-side]', { opacity: 0, x: (i) => (i ? 40 : -40), duration: 2, delay: 1.3 })
      gsap.to(el, { yPercent: -14, opacity: 0, ease: 'none', scrollTrigger: { trigger: el, start: 'top top', end: 'bottom top', scrub: true } })
    }, el)
    return () => ctx.revert()
  }, [reduced])

  return (
    <section ref={ref} id="top" className="relative h-[100svh] min-h-[640px]">
      <div ref={inner} className="relative mx-auto flex h-full max-w-[1600px] flex-col items-center justify-end px-5 pb-10 text-center sm:px-8 md:px-12 md:pb-12">
        <div data-side className="absolute left-5 top-[46%] hidden max-w-[14rem] text-left sm:left-8 md:left-12 lg:block">
          <AppTag color="#E2C275" name="PalliCore" who="Schools & teachers" />
        </div>
        <div data-side className="absolute right-5 top-[46%] hidden max-w-[14rem] text-right sm:right-8 md:right-12 lg:block">
          <AppTag color="#3EC6FF" name="PalliConnect" who="Parents & students" align="right" />
        </div>

        <p data-fade className="t-label mb-4">
          A Do It Global product
        </p>
        <h1 className="sr-only">Palli — your school’s own app, one connected ecosystem for the entire school</h1>
        <RevealText as="p" immediate delay={0.3} text="PALLI" className="t-display -mb-2 tracking-[-0.02em]" wordClassName={() => 'text-gradient-violet'} />
        <RevealText as="p" immediate delay={0.7} stagger={0.04} text="Your school’s own app. One connected ecosystem." className="t-h3 mt-6 max-w-[24ch] text-bone" />
        <p data-fade className="mt-5 flex flex-wrap justify-center gap-x-3 gap-y-2 text-[0.8rem] text-bone/70 sm:text-[0.86rem]">
          {['Your name & crest', 'Only the features you need', 'Your own cloud database'].map((t) => (
            <span key={t} className="rounded-full border border-bone/15 bg-ink/40 px-3 py-1">
              {t}
            </span>
          ))}
        </p>
        <div data-fade className="mt-8 flex items-center gap-6 lg:hidden">
          <AppTag color="#E2C275" name="PalliCore" who="Schools & teachers" />
          <AppTag color="#3EC6FF" name="PalliConnect" who="Parents & students" />
        </div>
        <div data-fade className="mt-10 hidden md:block">
          <ScrollCue label="Enter" />
        </div>
      </div>
    </section>
  )
}

function AppTag({ color, name, who, align = 'left' }: { color: string; name: string; who: string; align?: 'left' | 'right' }) {
  return (
    <div className={`flex flex-col ${align === 'right' ? 'items-end' : 'items-start'}`}>
      <span className="flex items-center gap-2">
        <span className="h-2 w-2 rounded-full" style={{ background: color, boxShadow: `0 0 14px ${color}` }} />
        <span className="text-[1rem] font-medium tracking-[-0.01em] text-bone">{name}</span>
      </span>
      <span className="t-label mt-1.5 text-[0.62rem]">{who}</span>
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  Ecosystem intro — a breath between the hero and the apps          */
/* ---------------------------------------------------------------- */
export function EcosystemIntro() {
  const ref = useSection<HTMLElement>('intro')
  return (
    <section ref={ref} className="relative flex min-h-[90svh] items-center px-5 sm:px-8 md:px-12">
      <div className="mx-auto w-full max-w-[1600px]">
        <SectionLabel index="01">Two apps · one school</SectionLabel>
        <RevealText text={'Palli is two apps\nsharing one school.'} className="t-h1 mt-8 max-w-[16ch] text-bone" />
        <div className="mt-12 grid max-w-[60rem] gap-10 md:grid-cols-2">
          <p className="t-lead">
            <span className="text-bone">PalliCore</span> is where the school works — administrators, teachers and the day’s operations.
          </p>
          <p className="t-lead">
            <span className="text-bone">PalliConnect</span> is where families see it — parents and students, the moment it happens.
          </p>
        </div>
        <p className="t-lead mt-10 max-w-[44rem] text-bone/85">
          And every school gets both apps as its own — under its name, with its features, on its own private cloud.
        </p>
      </div>
    </section>
  )
}

/* ---------------------------------------------------------------- */
/*  The connection                                                    */
/* ---------------------------------------------------------------- */
const LINES = [
  { t: 'Parents and students see their school.', c: '#3EC6FF' },
  { t: 'Teachers manage learning.', c: '#C9A24A' },
  { t: 'Administrators manage operations.', c: '#E2C275' },
  { t: 'Palli connects all of them.', c: '#B79BFF' },
]

/** Real hand-offs between the two apps, taken from the source. */
const FLOWS = [
  { from: 'Teacher shares today’s update', to: 'Parents see “Today’s Learning”' },
  { from: 'Teacher posts a class diary note', to: 'It appears in every parent’s Diary' },
  { from: 'Parent sends a leave request', to: 'It reaches “Student leave · Parent requests”' },
  { from: 'Teacher enters marks', to: 'Results appear as subjects are published' },
]

export function Connection() {
  const sectionRef = useSection<HTMLElement>('connection')
  const root = useRef<HTMLElement | null>(null)
  const reduced = useReducedMotion()

  useLayoutEffect(() => {
    const el = root.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      const lines = gsap.utils.toArray<HTMLElement>('[data-line]')
      const flows = gsap.utils.toArray<HTMLElement>('[data-flow]')
      const tl = gsap.timeline({ scrollTrigger: { trigger: el, start: 'top top', end: 'bottom bottom', scrub: 0.8 } })
      tl.from('[data-conn-head]', { autoAlpha: 0, y: 30, duration: 0.5 }, 0)
      lines.forEach((l, i) => {
        const at = 0.4 + i
        tl.fromTo(l, { autoAlpha: 0, y: 40 }, { autoAlpha: 1, y: 0, duration: 0.35, ease: 'power3.out' }, at)
        if (i < lines.length - 1) tl.to(l, { autoAlpha: 0, y: -30, duration: 0.28, ease: 'power2.in' }, at + 0.62)
      })
      flows.forEach((f, i) => tl.fromTo(f, { autoAlpha: 0, x: 30 }, { autoAlpha: 1, x: 0, duration: 0.4, ease: 'power3.out' }, 3.6 + i * 0.35))
      tl.to({}, { duration: 0.8 })
    }, el)
    return () => ctx.revert()
  }, [reduced])

  const setRefs = (el: HTMLElement | null) => {
    root.current = el
    sectionRef(el)
  }

  return (
    <section ref={setRefs} id="connection" className={`relative ${reduced ? 'py-32' : 'h-[420svh]'}`}>
      <div className={reduced ? 'px-5 sm:px-8 md:px-12' : 'sticky-stage'}>
        <div className="mx-auto flex h-full max-w-[1600px] flex-col justify-between px-5 pb-12 pt-24 sm:px-8 md:px-12 md:pt-28">
          <div data-conn-head>
            <SectionLabel index="04">The connection</SectionLabel>
            <p className="t-h3 mt-5 max-w-[22ch] text-bone/85">What happens in PalliCore shows up in PalliConnect.</p>
          </div>

          <div className="grid items-end gap-10 lg:grid-cols-[1fr_24rem]">
            <div className={`relative ${reduced ? 'space-y-6' : 'min-h-[7rem] md:min-h-[9rem]'}`}>
              {LINES.map((l) => (
                <p key={l.t} data-line className={`t-h2 text-bone ${reduced ? '' : 'absolute inset-x-0 bottom-0'}`}>
                  <span className="mr-3 inline-block h-3 w-3 -translate-y-1 rounded-full align-middle" style={{ background: l.c, boxShadow: `0 0 16px ${l.c}` }} />
                  {l.t}
                </p>
              ))}
            </div>
            <ul className="flex flex-col gap-2.5" aria-label="Examples of how the apps connect">
              {FLOWS.map((f) => (
                <li key={f.from} data-flow className="glass rounded-2xl px-4 py-2.5 sm:py-3">
                  <span className="flex items-center gap-2 text-[0.82rem] text-bone/90">
                    <span className="h-1.5 w-1.5 rounded-full bg-[#E2C275]" />
                    {f.from}
                  </span>
                  <span className="mt-1.5 flex items-center gap-2 text-[0.82rem] text-mute">
                    <span className="h-1.5 w-1.5 rounded-full bg-[#3EC6FF]" />
                    {f.to}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ---------------------------------------------------------------- */
/*  Philosophy                                                        */
/* ---------------------------------------------------------------- */
const ROLES = [
  { r: 'Students', t: 'See their day, their homework and how they are growing.', c: '#7FB2FF' },
  { r: 'Parents', t: 'Stay close to school life without having to chase anyone.', c: '#3EC6FF' },
  { r: 'Teachers', t: 'Spend the day on the class, not on paperwork.', c: '#C9A24A' },
  { r: 'Administrators', t: 'See the whole school and act on what needs attention.', c: '#E2C275' },
]

export function Philosophy() {
  const sectionRef = useSection<HTMLElement>('philosophy')
  const root = useRef<HTMLElement | null>(null)
  const reduced = useReducedMotion()

  useLayoutEffect(() => {
    const el = root.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      const tl = gsap.timeline({ scrollTrigger: { trigger: el, start: 'top top', end: 'bottom bottom', scrub: 0.8 } })
      tl.from('[data-ph-head] > *', { autoAlpha: 0, y: 50, stagger: 0.2, duration: 0.6, ease: 'power3.out' }, 0)
      tl.from('[data-role]', { autoAlpha: 0, y: 30, stagger: 0.3, duration: 0.5, ease: 'power3.out' }, 0.7)
      tl.to({}, { duration: 1 })
    }, el)
    return () => ctx.revert()
  }, [reduced])

  const setRefs = (el: HTMLElement | null) => {
    root.current = el
    sectionRef(el)
  }

  return (
    <section ref={setRefs} id="philosophy" className={`relative ${reduced ? 'py-32' : 'h-[260svh]'}`}>
      <div className={reduced ? '' : 'sticky-stage'}>
        <div className="mx-auto flex h-full max-w-[1600px] flex-col justify-between px-5 pb-12 pt-24 text-center sm:px-8 md:px-12 md:pt-28">
          <div data-ph-head>
            <SectionLabel index="12" className="justify-center">
              The idea
            </SectionLabel>
            <h2 className="t-h1 mx-auto mt-6 text-bone">
              One school.
              <br />
              <span className="text-gradient-violet">One connected ecosystem.</span>
            </h2>
          </div>
          <div className="grid grid-cols-2 gap-x-5 gap-y-4 text-left sm:gap-6 lg:grid-cols-4">
            {ROLES.map((r) => (
              <div key={r.r} data-role className="border-t pt-3 sm:pt-4" style={{ borderColor: `${r.c}55` }}>
                <p className="text-[0.95rem] font-medium tracking-[-0.01em] text-bone sm:text-[1.05rem]">{r.r}</p>
                <p className="mt-1.5 text-[0.8rem] leading-snug text-mute sm:mt-2 sm:text-[0.92rem] sm:leading-relaxed">{r.t}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

/* ---------------------------------------------------------------- */
/*  Finale                                                            */
/* ---------------------------------------------------------------- */
export function Finale() {
  const ref = useSection<HTMLElement>('finale')
  const mail = `mailto:${SITE.email}?subject=${encodeURIComponent('Bringing Palli to our school')}`
  return (
    <section ref={ref} id="contact" className="relative">
      <div className="flex min-h-[110svh] flex-col items-center justify-end px-5 pb-12 text-center sm:px-8 sm:pb-24 md:px-12">
        <RevealText as="h2" text="PALLI" className="t-display tracking-[-0.02em]" wordClassName={() => 'text-gradient-violet'} />
        <RevealText as="p" text="Your school’s own app — connecting the school, beyond the classroom." className="t-h3 mt-6 max-w-[26ch] text-bone" stagger={0.04} />
        <div className="mt-12 flex flex-wrap justify-center gap-3">
          <MagneticButton href={mail} variant="violet">
            Get your school’s own app
            <Arrow />
          </MagneticButton>
          <MagneticButton href={`mailto:${SITE.email}`} variant="ghost">
            Talk to us
          </MagneticButton>
        </div>
      </div>
      <footer className="border-t border-line bg-ink/80">
        <div className="mx-auto flex max-w-[1600px] flex-col gap-4 px-5 py-8 text-[0.8rem] text-mute sm:px-8 md:flex-row md:items-center md:justify-between md:px-12">
          <a href="/" className="flex items-center gap-2 text-bone/80 hover:text-bone">
            Palli is a product of <span className="font-medium text-bone">{SITE.company}</span> ↗
          </a>
          <p>App interfaces shown are recreations of PalliConnect and PalliCore with illustrative sample data.</p>
          <p>
            © {SITE.year} {SITE.company}
          </p>
        </div>
      </footer>
    </section>
  )
}
