import { mdiServerNetwork, mdiShieldCheckOutline, mdiLockOutline, mdiAccountKeyOutline, mdiDatabaseOutline, mdiCellphone, mdiLoginVariant, mdiQrcode, mdiFileDocumentOutline } from '@mdi/js'
import { DeviceFrame } from '../../components/DeviceFrame'
import { Icon } from '../../components/Primitives'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { remap } from '../../lib/math'
import { CENTRES, type Centre } from '../../data/nuvaraCentres'
import { CentreSignInScreen } from '../../screens/nuvara/BrandScreens'
import { FeatureLayout, useFeature, useScrub } from '../palli/Features'
import { Crossfade } from '../palli/Custom'
import { NV_ORANGE, NV_SKY } from './Story'

const brandPhone = { width: 'min(19rem, 46vw)', height: 'min(62svh, 38rem, 105vw, calc(100svh - 24rem))' }

/** Where a centre's name shows up in its app. */
const PLACES = [
  { icon: mdiCellphone, t: 'On every family’s phone', d: 'The app carries your centre’s name' },
  { icon: mdiLoginVariant, t: 'At sign-in', d: 'Parents, therapists and admins sign in to your centre' },
  { icon: mdiQrcode, t: 'On every UPI payment', d: 'Families pay your centre, by name' },
  { icon: mdiFileDocumentOutline, t: 'On receipts and reports', d: 'Fee receipts and assessment PDFs' },
]

/* ---------------------------------------------------------------- */
/*  Your centre's own app                                             */
/* ---------------------------------------------------------------- */
export function OwnCentreApp() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('your-app')
  const p = useScrub(root, 60, reduced)
  const idx = reduced ? 0 : Math.min(CENTRES.length - 1, Math.floor(remap(p, 0.1, 0.9) * CENTRES.length))
  const centre = CENTRES[idx]

  return (
    <FeatureLayout
      id="your-app"
      index="02"
      label="Your centre’s own app"
      accent={NV_ORANGE}
      title="Your centre’s name on the app."
      text="Every centre gets Nuvara as its own. Families install your centre’s app, sign in to your centre and pay your centre — under your name, from the first screen to the last receipt."
      mobileText="Every centre gets Nuvara under its own name — from the sign-in screen to the last receipt."
      facts={['Your centre’s name on the app', 'Its own server for its records', 'Set up for the way your centre works']}
      sectionRef={set}
      reduced={reduced}
      height={300}
      wideVisual
    >
      <div className="flex w-full items-center justify-center gap-5 sm:gap-10">
        <div className="hidden w-full max-w-[18rem] flex-col gap-2.5 sm:flex">
          <span className="t-label mb-1 text-[0.6rem]">Where your name appears</span>
          {PLACES.map((pl) => (
            <div key={pl.t} className="glass flex items-center gap-3 rounded-2xl px-3.5 py-3">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl" style={{ background: `${centre.glow}1f` }}>
                <Icon path={pl.icon} size={18} color={centre.glow} />
              </span>
              <span className="min-w-0">
                <span className="block text-[0.86rem] text-bone">{pl.t}</span>
                <span className="block truncate text-[0.74rem] text-mute">{pl.d}</span>
              </span>
            </div>
          ))}
        </div>

        <div className="flex flex-col items-center gap-4">
          <DeviceFrame kind="phone" style={brandPhone} screenBg="#F5F6FB" label={`The app as ${centre.name}`}>
            <Crossfade index={idx} items={CENTRES.map((c) => <CentreSignInScreen key={c.short} centre={c} />)} />
          </DeviceFrame>
          <CentreChips active={idx} />
        </div>
      </div>
    </FeatureLayout>
  )
}

function CentreChips({ active }: { active: number }) {
  return (
    <div className="flex flex-wrap justify-center gap-1.5" aria-hidden>
      {CENTRES.map((c, i) => (
        <span
          key={c.short}
          className="flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[0.7rem] transition-all duration-500"
          style={{ borderColor: i === active ? `${c.glow}88` : 'rgba(237,234,227,.1)', background: i === active ? `${c.glow}26` : 'transparent', color: i === active ? '#fff' : 'rgba(237,234,227,.5)' }}
        >
          <span className="h-1.5 w-1.5 rounded-full" style={{ background: c.glow }} />
          {c.short}
        </span>
      ))}
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  A server for every centre                                         */
/* ---------------------------------------------------------------- */
const POINTS = [
  { icon: mdiServerNetwork, t: 'A dedicated server per centre', d: 'Your centre’s records live on a server set up for your centre alone — never alongside another centre’s.' },
  { icon: mdiShieldCheckOutline, t: 'Separate by design', d: 'Your centre’s app is built to connect only to your centre’s server.' },
  { icon: mdiLockOutline, t: 'Encrypted connections', d: 'Everything between the app and your server travels over encrypted connections.' },
  { icon: mdiAccountKeyOutline, t: 'Access by role', d: 'Families see their own children, therapists the children in their sessions, the admin the whole centre.' },
]

export function OwnServer() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('server')
  const p = useScrub(root, 40, reduced)
  const shown = reduced ? 3 : p < 0.25 ? 1 : p < 0.48 ? 2 : 3
  const secure = reduced || p > 0.62
  const point = reduced ? 0 : Math.min(POINTS.length - 1, Math.floor(remap(p, 0.1, 0.95) * POINTS.length))

  return (
    <FeatureLayout
      id="server"
      index="09"
      label="A server for every centre"
      accent={NV_SKY}
      title="Your centre’s own server."
      mobileText="Every centre gets its own secure server. Your children’s, therapists’ and fee records stay on it — nowhere else."
      text="We run a separate, secure server for every centre. Your children’s assessments and progress, your therapists’ details and your fee records stay on your centre’s server — and nowhere else."
      sectionRef={set}
      reduced={reduced}
      height={260}
      wideVisual
    >
      <div className="flex w-full flex-col items-center gap-5">
        <div className="grid w-full max-w-[40rem] grid-cols-3 gap-2 sm:gap-5" role="img" aria-label="Three centres, each connected only to its own server">
          {CENTRES.map((c, i) => (
            <CentreServer key={c.short} centre={c} visible={i < shown} secure={secure} />
          ))}
        </div>
        <div className="glass w-full max-w-[40rem] rounded-2xl px-4 py-3 lg:hidden">
          <span className="flex items-center gap-2 text-[0.86rem] text-bone">
            <Icon path={POINTS[point].icon} size={18} color={NV_SKY} />
            {POINTS[point].t}
          </span>
          <span className="mt-1 block text-[0.78rem] leading-snug text-mute">{POINTS[point].d}</span>
        </div>
        <ul className="hidden w-full max-w-[40rem] grid-cols-2 gap-3 lg:grid">
          {POINTS.map((c, i) => (
            <li key={c.t} className={`rounded-2xl border px-4 py-3 transition-colors duration-500 ${i === point ? 'border-[#36A9E0]/40 bg-white/[0.06]' : 'border-white/[0.07] bg-white/[0.02]'}`}>
              <span className="flex items-center gap-2 text-[0.88rem] text-bone">
                <Icon path={c.icon} size={18} color={NV_SKY} />
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

function CentreServer({ centre, visible, secure }: { centre: Centre; visible: boolean; secure: boolean }) {
  return (
    <div className={`flex flex-col items-center transition-all duration-700 ${visible ? 'translate-y-0 opacity-100' : 'translate-y-6 opacity-0'}`}>
      <div className="glass flex w-full flex-col items-center gap-1.5 rounded-2xl px-2 py-3">
        <img src="/brand/nuvara-mark.webp" alt="" width={27} height={30} className="h-[30px] w-auto" />
        <span className="w-full truncate text-center text-[0.68rem] text-bone sm:text-[0.8rem]">{centre.short}</span>
        <span className="t-label text-[0.5rem] sm:text-[0.56rem]">App</span>
      </div>
      <div className="relative h-10 w-px overflow-hidden sm:h-14" style={{ background: `${centre.glow}44` }}>
        <span className="cloud-pulse absolute inset-x-0 h-3" style={{ background: centre.glow }} />
      </div>
      <div className="relative flex w-full flex-col items-center gap-1.5 rounded-2xl border px-2 py-3" style={{ borderColor: `${centre.glow}55`, background: `linear-gradient(180deg, ${centre.glow}26, rgba(1,0,57,.45))` }}>
        <Icon path={mdiDatabaseOutline} size={30} color={centre.glow} />
        <span className="w-full truncate text-center text-[0.64rem] text-bone sm:text-[0.76rem]">{centre.short} server</span>
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
