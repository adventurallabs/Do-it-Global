import { mdiWifiOff, mdiShieldLockOutline, mdiAccountKeyOutline, mdiCellphoneLock, mdiKeyChain } from '@mdi/js'
import { DeviceFrame } from '../../components/DeviceFrame'
import { Icon, SectionLabel } from '../../components/Primitives'
import { Reveal } from '../../components/Reveal'
import { RevealText } from '../../components/RevealText'
import { useSection } from '../../hooks/useSection'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { remap } from '../../lib/math'
import { FeatureLayout, phoneBox, useFeature, useScrub } from '../palli/Features'
import { ParentHomeScreen } from '../../screens/nuvara/ParentScreens'
import { NV_ORANGE, NV_SKY } from './Story'

/** Taken from the app's README: offline mode, the rules the database enforces, and who sees what. */
const POINTS = [
  { icon: mdiWifiOff, t: 'Works without a signal', d: 'Each phone keeps a small snapshot — the week, bills and messages — and shows it offline, then catches up as soon as the connection returns.' },
  { icon: mdiShieldLockOutline, t: 'Rules kept by the database', d: 'No double-booking, no payment above what’s due, no UPI reference used twice — the database refuses them, whatever is sent.' },
  { icon: mdiAccountKeyOutline, t: 'Everyone sees only their own', d: 'Families see their own children, therapists the children in their sessions. Salaries are for the admin alone.' },
  { icon: mdiCellphoneLock, t: 'Nothing leaves in a backup', d: 'Sign-in tokens and children’s details are kept out of phone backups and phone-to-phone transfers.' },
  { icon: mdiKeyChain, t: 'Logins made for you', d: 'Adding a therapist or a child creates their login. The first sign-in sets a private password; only the admin can reset it.' },
]

export function TrustFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('trust')
  const p = useScrub(root, 40, reduced)
  const point = reduced ? 0 : Math.min(POINTS.length - 1, Math.floor(remap(p, 0.08, 0.95) * POINTS.length))
  const network = reduced ? undefined : p < 0.22 ? 'offline' : p < 0.4 ? 'online' : undefined

  return (
    <FeatureLayout
      id="trust"
      index="10"
      label="Built to be relied on"
      accent={NV_SKY}
      title="For real centres, and real networks."
      text="Nuvara keeps working when the network doesn’t, and the rules that matter are enforced by the database itself — not just by the app on the screen."
      mobileText="It keeps working offline, and the rules that matter are enforced by the database itself."
      sectionRef={set}
      reduced={reduced}
      height={280}
      wideVisual
    >
      <div className="flex w-full flex-col items-center justify-center gap-4 sm:flex-row sm:gap-6 lg:gap-12">
        <div>
          <DeviceFrame kind="phone" style={phoneBox} screenBg="#F5F6FB" label="Nuvara parent home while offline">
            <ParentHomeScreen network={network} confirmed />
          </DeviceFrame>
        </div>
        <div className="flex w-full max-w-[30rem] flex-col gap-2.5">
          {POINTS.map((c, i) => (
            <div key={c.t} className={`rounded-2xl border px-4 py-3 transition-colors duration-500 ${i === point ? 'border-[#36A9E0]/45 bg-white/[0.07]' : 'border-white/[0.07] bg-white/[0.02]'} ${i === point ? '' : 'max-lg:hidden'}`}>
              <span className="flex items-center gap-2 text-[0.9rem] text-bone">
                <Icon path={c.icon} size={18} color={i === point ? NV_SKY : 'rgba(237,234,227,.55)'} />
                {c.t}
              </span>
              <span className="mt-1 block text-[0.8rem] leading-snug text-mute">{c.d}</span>
            </div>
          ))}
        </div>
      </div>
    </FeatureLayout>
  )
}

/* ---------------------------------------------------------------- */
/*  How a centre gets Nuvara                                          */
/* ---------------------------------------------------------------- */
const STEPS = [
  { t: 'Tell us how your centre works', d: 'Your therapies and fee per session, your timings, and the assessment form you use today.' },
  { t: 'We make the app yours', d: 'Your centre’s name on the app, its own server for your records, your therapies and fees, and your UPI ID.' },
  { t: 'Add therapists and children', d: 'Logins are created as you add them: therapists sign in with their mobile number, families with the child’s ID.' },
  { t: 'Plan the week and go live', d: 'Build the first week’s timetable — or copy last week’s in one tap — and families confirm their slots in the app.' },
]

export function NuvaraSetup() {
  const ref = useSection<HTMLElement>('setup')
  return (
    <section ref={ref} id="setup" className="relative px-5 py-28 sm:px-8 md:px-12 md:py-40">
      <div className="mx-auto max-w-[1600px]">
        <SectionLabel index="11" accent={NV_ORANGE}>
          Getting started
        </SectionLabel>
        <RevealText text={'From your centre’s paperwork\nto your centre’s app.'} className="t-h2 mt-6 max-w-[22ch] text-bone" />
        <Reveal stagger={0.12} className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {STEPS.map((s, i) => (
            <div key={s.t} className="glass rounded-[24px] p-6">
              <span className="font-mono text-[0.8rem]" style={{ color: '#ff9a6e' }}>
                0{i + 1}
              </span>
              <h3 className="mt-6 text-[1.2rem] font-medium leading-snug tracking-[-0.02em] text-bone">{s.t}</h3>
              <p className="mt-3 text-[0.92rem] leading-relaxed text-mute">{s.d}</p>
            </div>
          ))}
        </Reveal>
      </div>
    </section>
  )
}
