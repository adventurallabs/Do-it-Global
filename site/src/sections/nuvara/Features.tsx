import { useLayoutEffect } from 'react'
import { mdiCalendarRemoveOutline, mdiCalendarSync, mdiChatOutline, mdiQrcode, mdiCheckCircle, mdiArrowRight } from '@mdi/js'
import { gsap } from '../../animations/gsap'
import { DeviceFrame } from '../../components/DeviceFrame'
import { Icon } from '../../components/Primitives'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { useIsDesktop } from '../../hooks/useMediaQuery'
import { remap } from '../../lib/math'
import { Captioned, FeatureLayout, phoneBox, useFeature, useScrub } from '../palli/Features'
import { ParentFeesScreen, ParentHomeScreen, ParentProgressScreen } from '../../screens/nuvara/ParentScreens'
import { RatingRow, TherapistTodayScreen } from '../../screens/nuvara/TherapistScreens'
import { AdminHomeScreen, AssessmentScreen, SECTIONS } from '../../screens/nuvara/AdminScreens'
import { NV_LILAC, NV_ORANGE, NV_SKY } from './Story'

function FlowDots({ active }: { active: boolean }) {
  return (
    <div aria-hidden className={`hidden flex-col items-center gap-3 transition-opacity duration-700 sm:flex ${active ? 'opacity-100' : 'opacity-25'}`}>
      <div className="relative h-px w-16 overflow-hidden bg-gradient-to-r from-[#EA501E]/40 to-[#36A9E0]/40 lg:w-24">
        <span className="flow-dot absolute top-1/2 h-1.5 w-6 -translate-y-1/2 rounded-full bg-gradient-to-r from-[#EA501E] to-[#36A9E0]" />
      </div>
      <img src="/brand/nuvara-mark.webp" alt="" width={20} height={22} className="h-5 w-auto opacity-80" />
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  Attendance: one tap at the centre, seen at home                   */
/* ---------------------------------------------------------------- */
export function AttendanceFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('attendance')
  const p = useScrub(root, 40, reduced)
  const aarav = p > 0.18 ? 'present' : null
  const anaya = p > 0.32 ? 'present' : null
  const attended = p > 0.45
  const rated = p > 0.72
  return (
    <FeatureLayout
      id="features"
      index="04"
      label="Attendance"
      accent="#22C55E"
      title="One tap at the centre. Seen at home."
      text="The therapist marks the session in Nuvara. The family’s Today list turns from “In session now” to “Attended” — and once the report is in, the rating and note follow."
      mobileText="The therapist marks the session. The family sees “Attended”, then the rating and the note."
      facts={['Present, late or absent, per child', 'Opens 15 minutes before the start', 'Only attended sessions are billed']}
      sectionRef={set}
      reduced={reduced}
      wideVisual
    >
      <div className="flex w-full items-center justify-center gap-3 sm:gap-8">
        <Captioned caption="Therapist · Today" color={NV_ORANGE}>
          <DeviceFrame kind="phone" style={phoneBox} screenBg="#F5F6FB" label="Nuvara therapist attendance">
            <TherapistTodayScreen aarav={aarav} anaya={anaya} scroll={300} />
          </DeviceFrame>
        </Captioned>
        <FlowDots active={p > 0.15 && p < 0.95} />
        <Captioned caption="Family · Home" color={NV_SKY}>
          <DeviceFrame kind="phone" style={phoneBox} screenBg="#F5F6FB" label="Nuvara parent home, today's sessions">
            <ParentHomeScreen attended={attended} rated={rated} scroll={560} />
          </DeviceFrame>
        </Captioned>
      </div>
    </FeatureLayout>
  )
}

/* ---------------------------------------------------------------- */
/*  Progress: a rating after every session becomes a journey          */
/* ---------------------------------------------------------------- */
const REPORTS = [
  { d: 'Mon, 6 Jul', r: 4, n: 'Settling in. Needed help to stay with the picture cards.' },
  { d: 'Mon, 3 Aug', r: 6, n: 'Took turns in the sound game and named 6 of 10 cards.' },
  { d: 'Mon, 7 Sep', r: 7, n: 'Clear /s/ sounds at the start of words, most of the time.' },
  { d: 'Mon, 5 Oct', r: 8, n: 'Joined every round and said all his /s/ words clearly.' },
]

export function ProgressFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('progress-story')
  const p = useScrub(root, 60, reduced)
  const grow = remap(p, 0.08, 0.8)
  const at = Math.min(REPORTS.length - 1, Math.floor(remap(p, 0.05, 0.85) * REPORTS.length))
  const rep = REPORTS[at]
  return (
    <FeatureLayout
      id="progress-story"
      index="05"
      label="Progress"
      accent="#7FB2FF"
      title="Growth you can actually see."
      text="After every session the therapist rates it from 0 to 10 and writes a note for home. The ratings become a chart of the journey since the first day — overall, per therapy, and any day in detail."
      mobileText="A 0–10 rating and a note after every session, charted since the first day."
      facts={['0–10 after every session', 'Doing well · developing · needs support', 'Per therapy, and any day in detail']}
      sectionRef={set}
      reduced={reduced}
      wideVisual
    >
      <div className="relative flex w-full items-center justify-center gap-10">
        <div className="hidden w-full max-w-[24rem] xl:block">
          <div className="glass rounded-[24px] p-5">
            <span className="t-label text-[0.6rem]">Speech Therapy · session report</span>
            <p className="mt-3 text-[0.95rem] text-bone">{rep.d}</p>
            <div className="nv mt-3 rounded-2xl bg-white p-3">
              <RatingRow value={rep.r} />
            </div>
            <p className="mt-4 min-h-[3em] text-[0.9rem] leading-relaxed text-bone/80">&ldquo;{rep.n}&rdquo;</p>
            <div className="mt-4 flex items-center gap-2">
              {REPORTS.map((r, i) => (
                <span key={r.d} className="h-1.5 flex-1 rounded-full transition-colors duration-500" style={{ background: i <= at ? (r.r >= 7 ? '#22C55E' : '#F59E0B') : 'rgba(237,234,227,.12)' }} />
              ))}
            </div>
          </div>
        </div>
        <DeviceFrame kind="phone" style={phoneBox} screenBg="#F5F6FB" label="Nuvara parent progress chart">
          <ParentProgressScreen grow={grow} />
        </DeviceFrame>
      </div>
    </FeatureLayout>
  )
}

/* ---------------------------------------------------------------- */
/*  The Pediatric OT assessment                                       */
/* ---------------------------------------------------------------- */
const CHANGES = ['Walking: Delayed → Present', 'Pincer grasp: Emerging → Present', 'Inattentive: Moderate → Mild']

export function AssessmentFeature() {
  const reduced = useReducedMotion()
  const desktop = useIsDesktop()
  const { root, set } = useFeature('assessment')
  const p = useScrub(root, 40, reduced)
  const answered = reduced ? 6 : Math.round(remap(p, 0.1, 0.7) * 6)
  const changes = reduced ? 3 : Math.round(remap(p, 0.7, 0.92) * 3)
  return (
    <FeatureLayout
      id="assessment"
      index="06"
      label="Pediatric OT assessment"
      accent={NV_ORANGE}
      title="The paper assessment, made fast."
      text="The centre’s five-page Pediatric OT form becomes 18 sections of one-tap answers. Follow-up questions appear only when an answer needs them, everything saves as you go — even offline — and the report downloads as a PDF."
      mobileText="18 sections of one-tap answers that save as you go, with a PDF report at the end."
      facts={['18 sections, one per page', 'Saves as you go — even offline', 'What changed since the last one, item by item']}
      sectionRef={set}
      reduced={reduced}
      height={260}
      wideVisual
    >
      <div className="relative flex w-full flex-col items-center justify-center gap-5">
        <DeviceFrame
          kind={desktop ? 'tablet' : 'phone'}
          style={desktop ? { width: 'min(54rem, 58vw)', height: 'min(64svh, 38rem)' } : phoneBox}
          screenBg="#F5F6FB"
          label="Nuvara Pediatric OT assessment, behaviour section"
        >
          <AssessmentScreen answered={answered} />
        </DeviceFrame>
        <div className="flex flex-wrap justify-center gap-2" aria-live="polite">
          <span className="glass flex items-center gap-2 rounded-full px-3 py-1.5 text-[0.78rem] text-bone/85">
            <span className="h-1.5 w-1.5 rounded-full bg-[#EA501E]" />
            {answered < 6 ? `Section 8 of ${SECTIONS.length} · Behaviour` : 'Behaviour · all recorded'}
          </span>
          {CHANGES.slice(0, changes).map((c) => (
            <span key={c} className="glass xfade-in hidden items-center gap-2 rounded-full px-3 py-1.5 text-[0.78rem] text-bone/85 sm:flex">
              <Icon path={mdiCheckCircle} size={14} color="#22C55E" />
              {c}
            </span>
          ))}
        </div>
      </div>
    </FeatureLayout>
  )
}

/* ---------------------------------------------------------------- */
/*  Fees & UPI                                                        */
/* ---------------------------------------------------------------- */
export function FeesFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('fees')
  const p = useScrub(root, 20, reduced)
  const paid = p > 0.55
  return (
    <FeatureLayout
      id="fees"
      index="07"
      label="Fees & UPI"
      accent={NV_SKY}
      title="Weekly bills. Paid with UPI. No gateway."
      text="Each week is billed for the sessions attended, at the child’s own fee per session. Families pay from any UPI app straight to the centre’s UPI ID — the server fixes the amount and reference, and receipts are drawn on the phone."
      mobileText="Billed weekly for sessions attended, and paid from any UPI app — with no gateway in between."
      facts={['Only attended sessions are charged', 'No payment gateway, no 2% fee', 'A payment can never exceed what’s due']}
      sectionRef={set}
      reduced={reduced}
    >
      <div className="relative flex items-center justify-center">
        <DeviceFrame kind="phone" style={phoneBox} screenBg="#F5F6FB" label="Nuvara parent fees">
          <ParentFeesScreen paid={paid} />
        </DeviceFrame>
        <div className={`glass absolute -right-4 top-[18%] hidden w-[15rem] rounded-2xl px-4 py-3.5 transition-all duration-700 sm:block lg:-right-52 ${paid ? 'translate-y-0 opacity-100' : 'translate-y-4 opacity-0'}`}>
          <span className="flex items-center gap-2 text-[0.9rem] text-bone">
            <span className="h-2 w-2 rounded-full bg-[#22C55E] shadow-[0_0_12px_#22C55E]" />
            Payment successful
          </span>
          <span className="mt-1 block pl-4 text-[0.78rem] text-mute">₹3,300 · UPI reference 627819304512</span>
        </div>
        <div className={`glass absolute -left-4 bottom-[16%] hidden w-[15rem] rounded-2xl px-4 py-3.5 transition-all delay-200 duration-700 sm:block lg:-left-56 ${paid ? 'translate-y-0 opacity-100' : 'translate-y-4 opacity-0'}`}>
          <span className="flex items-center gap-2 text-[0.9rem] text-bone">
            <span className="h-2 w-2 rounded-full" style={{ background: NV_LILAC, boxShadow: `0 0 12px ${NV_LILAC}` }} />
            The centre · Fees
          </span>
          <span className="mt-1 block pl-4 text-[0.78rem] text-mute">Outstanding ₹10,900 → ₹7,600</span>
        </div>
      </div>
    </FeatureLayout>
  )
}

/* ---------------------------------------------------------------- */
/*  Families → the centre: every action lands where it's acted on      */
/* ---------------------------------------------------------------- */
const SENDS = [
  { icon: mdiChatOutline, who: 'Diya’s father', what: 'Sends a message', detail: '“We will be there by 10.”', lands: 0 },
  { icon: mdiQrcode, who: 'Aarav’s mother', what: 'Pays ₹3,300 with UPI', detail: 'Week of 28 Sep', lands: 2 },
  { icon: mdiCalendarRemoveOutline, who: 'Meher’s mother', what: 'Can’t make it', detail: 'Today 3:30 PM · Fever', lands: 3 },
  { icon: mdiCalendarSync, who: 'Aarav’s mother', what: 'Asks for another slot', detail: 'Friday, after 3 PM', lands: 99 },
]

export function RequestsFeature() {
  const reduced = useReducedMotion()
  const { root, set } = useFeature('requests')
  const p = useScrub(root, 40, reduced)
  const active = Math.min(SENDS.length - 1, Math.floor(remap(p, 0.1, 0.9) * SENDS.length))
  const lands = p > 0.08 ? SENDS[active].lands : -1

  useLayoutEffect(() => {
    const el = root.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      const packets = gsap.utils.toArray<HTMLElement>('[data-packet]')
      const target = el.querySelector<HTMLElement>('[data-inbox]')
      const tl = gsap.timeline({ scrollTrigger: { trigger: el, start: 'top top', end: 'bottom bottom', scrub: 0.7, invalidateOnRefresh: true } })
      packets.forEach((pk, i) => {
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
  }, [reduced, root])

  return (
    <FeatureLayout
      id="requests"
      index="08"
      label="Families → the centre"
      accent="#B79BFF"
      title="Families ask once. The centre sees it at once."
      text="A message, a payment, an absence or a request for another slot — each lands on the admin’s Home where it will be acted on, with requests that need an answer before the session kept on top."
      mobileText="Messages, payments, absences and slot requests land on the admin’s Home, ready to act on."
      sectionRef={set}
      reduced={reduced}
      wideVisual
    >
      <div className="flex w-full items-center justify-center gap-6 lg:gap-16">
        <div className="hidden w-full max-w-[20rem] flex-col gap-3 md:flex">
          <span className="t-label mb-1 flex items-center gap-2 text-[0.64rem]">
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: NV_SKY }} />
            From families
          </span>
          {SENDS.map((s, i) => (
            <div key={s.what} className={`relative rounded-2xl border px-4 py-3 transition-all duration-500 ${i === active ? 'border-[#36A9E0]/50 bg-white/[0.07]' : 'border-white/[0.08] bg-white/[0.03]'}`}>
              <span className="flex items-center gap-3">
                <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-[#36A9E0]/12">
                  <Icon path={s.icon} size={18} color={NV_SKY} />
                </span>
                <span>
                  <span className="block text-[0.88rem] text-bone">
                    {s.who} · {s.what}
                  </span>
                  <span className="block text-[0.76rem] text-mute">{s.detail}</span>
                </span>
              </span>
              <span data-packet aria-hidden className="absolute right-3 top-1/2 z-20 h-2.5 w-2.5 -translate-y-1/2 rounded-full bg-[#bfe6fa] opacity-0 shadow-[0_0_18px_6px_rgba(54,169,224,.55)]" />
            </div>
          ))}
          <span className="mt-1 flex items-center gap-2 text-[0.78rem] text-mute">
            <Icon path={mdiArrowRight} size={14} color="#9a99a1" />
            The admin&rsquo;s Home, on the right
          </span>
        </div>
        <div data-inbox>
          <DeviceFrame kind="phone" style={phoneBox} screenBg="#F5F6FB" label="Nuvara admin home, needs attention">
            <AdminHomeScreen focus={lands} scroll={lands === 99 ? 300 : 560} />
          </DeviceFrame>
        </div>
      </div>
    </FeatureLayout>
  )
}
