import { useEffect, useRef, useState, type ReactNode } from 'react'
import { mdiDatabaseOutline, mdiLockOutline, mdiShieldCheckOutline, mdiAccountKeyOutline, mdiServerNetwork, mdiPlus } from '@mdi/js'
import { DeviceFrame } from '../../components/DeviceFrame'
import { Icon, SectionLabel } from '../../components/Primitives'
import { Reveal } from '../../components/Reveal'
import { RevealText } from '../../components/RevealText'
import { useSection } from '../../hooks/useSection'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { BRANDS, MODULES, type SchoolBrand } from '../../data/brands'
import { AppIcon, BrandTodayScreen, Crest } from '../../screens/connect/BrandScreens'
import { remap } from '../../lib/math'
import { FeatureLayout, useFeature, useScrub } from './Features'

const brandPhone = { width: 'min(19rem, 46vw)', height: 'min(62svh, 38rem, 105vw, calc(100svh - 24rem))' }

/**
 * Stacks every item and shows one. A new item fades in *over* the previous
 * one, which stays painted underneath until it is covered — so a switch
 * never exposes an empty (white) screen, even while a phone is still
 * rasterising the new one.
 */
function Crossfade({ index, items }: { index: number; items: ReactNode[] }) {
  const [prev, setPrev] = useState(index)
  const last = useRef(index)
  useEffect(() => {
    if (index === last.current) return
    setPrev(last.current)
    last.current = index
    const t = setTimeout(() => setPrev(index), 650)
    return () => clearTimeout(t)
  }, [index])
  return (
    <>
      {items.map((item, i) => {
        const current = i === index
        const under = i === prev && !current
        return (
          <div
            key={i}
            className={`absolute inset-0 ${current && prev !== index ? 'xfade-in' : ''}`}
            style={{ visibility: current || under ? 'visible' : 'hidden', zIndex: current ? 2 : 1 }}
          >
            {item}
          </div>
        )
      })}
    </>
  )
}

/* ---------------------------------------------------------------- */
/*  Your school's own app — one build, re-branded per school          */
/* ---------------------------------------------------------------- */
export function OwnApp() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('ownapp')
  const p = useScrub(root, 60, reduced)
  const idx = reduced ? 0 : Math.min(BRANDS.length - 1, Math.floor(remap(p, 0.1, 0.9) * BRANDS.length))
  const brand = BRANDS[idx]

  return (
    <FeatureLayout
      id="your-app"
      index="02"
      label="Your school’s own app"
      accent="#B79BFF"
      title="Your school’s name on the app. Not ours."
      text="Palli isn’t a common school app with your school listed inside it. Every school gets the apps as its own — its name, its crest, its colours and its icon on every parent’s phone. Families open their school’s app."
      mobileText="Every school gets the apps as its own — its name, crest, colours and icon on every parent’s phone."
      facts={['Your school’s name and crest on every screen', 'Your colours throughout both apps', 'Your own app icon on parents’ phones']}
      sectionRef={set}
      reduced={reduced}
      height={300}
      wideVisual
    >
      <div className="flex w-full items-center justify-center gap-5 sm:gap-10">
        {/* The parent's home screen, with this school's icon among the apps */}
        <div className="hidden flex-col items-center gap-4 sm:flex">
          <div className="glass grid grid-cols-3 gap-4 rounded-[28px] p-5">
            {Array.from({ length: 8 }, (_, i) =>
              i === 4 ? (
                <span key={i} className="flex flex-col items-center gap-1.5">
                  <span className="relative block h-14 w-14">
                    {BRANDS.map((b, bi) => (
                      <span key={b.short} className="absolute inset-0 transition-opacity duration-500" style={{ opacity: bi === idx ? 1 : 0 }}>
                        <AppIcon brand={b} size={56} />
                      </span>
                    ))}
                  </span>
                  <span className="w-16 truncate text-center text-[0.68rem] text-bone">{brand.short}</span>
                </span>
              ) : (
                <span key={i} className="flex flex-col items-center gap-1.5">
                  <span className="block h-14 w-14 rounded-[14px] bg-white/[0.07]" />
                  <span className="block h-1.5 w-9 rounded-full bg-white/10" />
                </span>
              ),
            )}
          </div>
          <span className="t-label text-[0.6rem]">On a parent’s phone</span>
        </div>

        <div className="flex flex-col items-center gap-4">
          <DeviceFrame kind="phone" style={brandPhone} screenBg="#ffffff" label={`The parent app branded for ${brand.name}`}>
            <Crossfade index={idx} items={BRANDS.map((b) => <BrandTodayScreen key={b.short} brand={b} />)} />
          </DeviceFrame>
          <SchoolChips active={idx} />
        </div>
      </div>
    </FeatureLayout>
  )
}

function SchoolChips({ active }: { active: number }) {
  return (
    <div className="flex flex-wrap justify-center gap-1.5" aria-hidden>
      {BRANDS.map((b, i) => (
        <span
          key={b.short}
          className="flex items-center gap-1.5 rounded-full border py-1 pl-1 pr-2.5 text-[0.7rem] transition-all duration-500"
          style={{ borderColor: i === active ? `${b.soft}88` : 'rgba(237,234,227,.1)', background: i === active ? `${b.color}33` : 'transparent', color: i === active ? '#fff' : 'rgba(237,234,227,.5)' }}
        >
          <Crest brand={b} size={18} />
          {b.short}
        </span>
      ))}
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  Only the features you need — per-school feature switches          */
/* ---------------------------------------------------------------- */
const MODULE_STAGES = [
  { off: [] as string[], custom: false, caption: 'Every school starts from the full set of features.' },
  { off: ['bus_tracking'], custom: false, caption: 'No school buses? Bus tracking is switched off.' },
  { off: ['bus_tracking', 'fees'], custom: false, caption: 'Fees paid at the counter? The fee screens go too.' },
  { off: ['bus_tracking', 'fees'], custom: true, caption: 'Need something the apps don’t do yet? We build it into yours.' },
]

export function Modules() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('modules')
  const p = useScrub(root, 50, reduced)
  const stage = reduced ? 3 : p < 0.25 ? 0 : p < 0.47 ? 1 : p < 0.68 ? 2 : 3
  const st = MODULE_STAGES[stage]
  const enabled = new Set(MODULES.map((m) => m.key).filter((k) => !st.off.includes(k)))
  const brand = BRANDS[1]

  return (
    <FeatureLayout
      id="modules"
      index="03"
      label="Only what your school needs"
      accent="#86EFAC"
      title="The features you want. None you don’t."
      text="Each school’s app is set up with exactly the features that school uses. Anything you don’t need is switched off and disappears from the apps; anything new you need, we build and add — so it works the way your school already works."
      mobileText="Only the features your school uses are switched on — and anything new you need, we build and add."
      facts={['Features switched on or off for each school', 'New features built on request', 'Your own rules — like when parents are warned about attendance']}
      sectionRef={set}
      reduced={reduced}
      height={260}
      wideVisual
    >
      <div className="flex w-full items-center justify-center gap-8">
        <div className="w-full max-w-[26rem]">
          <div className="glass rounded-[24px] p-3 sm:p-4">
            <div className="mb-3 flex items-center justify-between px-1">
              <span className="flex items-center gap-2 text-[0.8rem] text-bone">
                <Crest brand={brand} size={20} />
                {brand.name}
              </span>
              <span className="t-label text-[0.56rem]">Features</span>
            </div>
            <ul className="grid grid-cols-2 gap-1 sm:gap-2" aria-label="Feature switches for an example school">
              {MODULES.map((m) => (
                <Toggle key={m.key} label={m.label} on={enabled.has(m.key)} always={m.always} />
              ))}
              <li
                className={`col-span-2 flex items-center gap-2 rounded-xl border border-dashed px-2.5 py-1.5 transition-all duration-500 sm:py-2 ${st.custom ? 'opacity-100' : 'opacity-0'}`}
                style={{ borderColor: '#86EFAC88', background: 'rgba(134,239,172,.08)' }}
                aria-hidden={!st.custom}
              >
                <span className="flex h-5 w-5 items-center justify-center rounded-md bg-[#86EFAC]">
                  <Icon path={mdiPlus} size={15} color="#052E1A" />
                </span>
                <span className="text-[0.74rem] text-bone sm:text-[0.8rem]">Your feature — built for your school</span>
              </li>
            </ul>
          </div>
          <p className="mt-3 min-h-[2.6em] text-center text-[0.82rem] leading-snug text-bone/80 sm:text-[0.9rem]" aria-live="polite">
            {st.caption}
          </p>
        </div>
        <div className="hidden lg:block">
          <DeviceFrame kind="phone" style={{ width: 'min(18rem, 30vw)', height: 'min(70svh, 37rem)' }} screenBg="#ffffff" label="The parent app showing only enabled features">
            <BrandTodayScreen brand={brand} enabled={enabled} custom={st.custom} />
          </DeviceFrame>
        </div>
      </div>
    </FeatureLayout>
  )
}

function Toggle({ label, on, always }: { label: string; on: boolean; always?: boolean }) {
  return (
    <li className={`flex items-center justify-between gap-1.5 rounded-xl px-2.5 py-1 transition-colors duration-500 sm:py-2 ${on ? 'bg-white/[0.06]' : 'bg-transparent'}`}>
      <span className={`truncate text-[0.72rem] transition-colors duration-500 sm:text-[0.8rem] ${on ? 'text-bone' : 'text-bone/35 line-through decoration-bone/30'}`}>{label}</span>
      {always ? (
        <Icon path={mdiLockOutline} size={13} color="rgba(237,234,227,.4)" title="Always on" />
      ) : (
        <span className="relative h-[14px] w-[24px] shrink-0 rounded-full transition-colors duration-500 sm:h-4 sm:w-7" style={{ background: on ? '#22C55E' : 'rgba(237,234,227,.15)' }}>
          <span className="absolute top-[2px] h-[10px] w-[10px] rounded-full bg-white transition-all duration-500 sm:h-3 sm:w-3" style={{ left: on ? 'calc(100% - 12px)' : '2px' }} />
        </span>
      )}
      <span className="sr-only">{always ? 'always on' : on ? 'on' : 'off'}</span>
    </li>
  )
}

/* ---------------------------------------------------------------- */
/*  A private cloud for every school                                  */
/* ---------------------------------------------------------------- */
const CLOUD_POINTS = [
  { icon: mdiServerNetwork, t: 'A dedicated database per school', d: 'Your records live in a cloud database set up for your school alone — never alongside another school’s.' },
  { icon: mdiShieldCheckOutline, t: 'Separate by design', d: 'Your school’s apps are built to connect only to your school’s database.' },
  { icon: mdiLockOutline, t: 'Encrypted connections', d: 'Everything between the apps and your database travels over encrypted connections.' },
  { icon: mdiAccountKeyOutline, t: 'Access by role', d: 'Parents see their own children, teachers their classes, administrators the whole school.' },
]

export function PrivateCloud() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('cloud')
  const p = useScrub(root, 40, reduced)
  const shown = reduced ? 3 : p < 0.25 ? 1 : p < 0.48 ? 2 : 3
  const secure = reduced || p > 0.62
  const point = reduced ? 0 : Math.min(CLOUD_POINTS.length - 1, Math.floor(remap(p, 0.1, 0.95) * CLOUD_POINTS.length))

  return (
    <FeatureLayout
      id="cloud"
      index="10"
      label="A private cloud for every school"
      accent="#3EC6FF"
      title="Your school’s own cloud database."
      mobileText="Every school gets its own secure cloud database. Your records stay in your school’s database — nowhere else."
      text="We run a separate, secure cloud database server for every school. Your students’, staff and fee records stay in your school’s database — and nowhere else."
      sectionRef={set}
      reduced={reduced}
      height={260}
      wideVisual
    >
      <div className="flex w-full flex-col items-center gap-5">
        <div className="grid w-full max-w-[40rem] grid-cols-3 gap-2 sm:gap-5" role="img" aria-label="Three schools, each connected only to its own database">
          {BRANDS.map((b, i) => (
            <SchoolCloud key={b.short} brand={b} visible={i < shown} secure={secure} />
          ))}
        </div>
        <div className="glass w-full max-w-[40rem] rounded-2xl px-4 py-3 lg:hidden">
          <span className="flex items-center gap-2 text-[0.86rem] text-bone">
            <Icon path={CLOUD_POINTS[point].icon} size={18} color="#3EC6FF" />
            {CLOUD_POINTS[point].t}
          </span>
          <span className="mt-1 block text-[0.78rem] leading-snug text-mute">{CLOUD_POINTS[point].d}</span>
        </div>
        <ul className="hidden w-full max-w-[40rem] grid-cols-2 gap-3 lg:grid">
          {CLOUD_POINTS.map((c, i) => (
            <li key={c.t} className={`rounded-2xl border px-4 py-3 transition-colors duration-500 ${i === point ? 'border-[#3EC6FF]/40 bg-white/[0.06]' : 'border-white/[0.07] bg-white/[0.02]'}`}>
              <span className="flex items-center gap-2 text-[0.88rem] text-bone">
                <Icon path={c.icon} size={18} color="#3EC6FF" />
                {c.t}
              </span>
              <span className="mt-1 block text-[0.78rem] leading-snug text-mute">{c.d}</span>
            </li>
          ))}
        </ul>
      </div>
    </FeatureLayout>
  )
}

function SchoolCloud({ brand, visible, secure }: { brand: SchoolBrand; visible: boolean; secure: boolean }) {
  return (
    <div className={`flex flex-col items-center transition-all duration-700 ${visible ? 'translate-y-0 opacity-100' : 'translate-y-6 opacity-0'}`}>
      <div className="glass flex w-full flex-col items-center gap-1.5 rounded-2xl px-2 py-3">
        <Crest brand={brand} size={34} />
        <span className="w-full truncate text-center text-[0.68rem] text-bone sm:text-[0.8rem]">{brand.short}</span>
        <span className="t-label text-[0.5rem] sm:text-[0.56rem]">Apps</span>
      </div>
      <div className="relative h-10 w-px overflow-hidden sm:h-14" style={{ background: `${brand.soft}44` }}>
        <span className="cloud-pulse absolute inset-x-0 h-3" style={{ background: brand.soft }} />
      </div>
      <div className="relative flex w-full flex-col items-center gap-1.5 rounded-2xl border px-2 py-3" style={{ borderColor: `${brand.soft}55`, background: `linear-gradient(180deg, ${brand.color}30, ${brand.deep}40)` }}>
        <Icon path={mdiDatabaseOutline} size={30} color={brand.soft} />
        <span className="w-full truncate text-center text-[0.64rem] text-bone sm:text-[0.76rem]">{brand.short} database</span>
        <span
          className={`absolute -right-2 -top-2 flex h-6 w-6 items-center justify-center rounded-full transition-all duration-500 ${secure ? 'scale-100 opacity-100' : 'scale-50 opacity-0'}`}
          style={{ background: '#22C55E', boxShadow: '0 0 14px #22C55E88' }}
        >
          <Icon path={mdiLockOutline} size={14} color="#052E1A" />
        </span>
      </div>
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  How a school gets Palli                                           */
/* ---------------------------------------------------------------- */
const STEPS = [
  { t: 'Tell us about your school', d: 'Your classes, your routines and the features you need — including anything the apps don’t do yet.' },
  { t: 'We make the apps yours', d: 'Your school’s name, crest, colours and app icon, with just the features you chose and any new ones built in.' },
  { t: 'We set up your private cloud', d: 'A dedicated database for your school, with accounts for administrators, teachers and parents.' },
  { t: 'Go live and keep growing', d: 'Families install your school’s app. As your needs change, we add, remove or build features.' },
]

export function Setup() {
  const ref = useSection<HTMLElement>('setup')
  return (
    <section ref={ref} id="setup" className="relative px-5 py-28 sm:px-8 md:px-12 md:py-40">
      <div className="mx-auto max-w-[1600px]">
        <SectionLabel index="11" accent="#B79BFF">
          Getting started
        </SectionLabel>
        <RevealText text={'From your school’s needs\nto your school’s app.'} className="t-h2 mt-6 max-w-[20ch] text-bone" />
        <Reveal stagger={0.12} className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {STEPS.map((s, i) => (
            <div key={s.t} className="glass rounded-[24px] p-6">
              <span className="font-mono text-[0.8rem] text-violet-soft">0{i + 1}</span>
              <h3 className="mt-6 text-[1.2rem] font-medium leading-snug tracking-[-0.02em] text-bone">{s.t}</h3>
              <p className="mt-3 text-[0.92rem] leading-relaxed text-mute">{s.d}</p>
            </div>
          ))}
        </Reveal>
      </div>
    </section>
  )
}
