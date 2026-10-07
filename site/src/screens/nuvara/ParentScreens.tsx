import type { ReactNode } from 'react'
import {
  mdiCheck,
  mdiChevronLeft,
  mdiChevronRight,
  mdiClipboardCheckOutline,
  mdiPlus,
  mdiMessageBadgeOutline,
  mdiCheckCircle,
  mdiPlayCircleOutline,
  mdiClockOutline,
  mdiCalendarRemoveOutline,
  mdiCalendarSync,
  mdiQrcode,
  mdiDownload,
  mdiStorefrontOutline,
  mdiEmoticonSickOutline,
  mdiStethoscope,
  mdiPartyPopper,
  mdiBagSuitcaseOutline,
  mdiNoteEditOutline,
  mdiSend,
  mdiCheckAll,
  mdiChartTimelineVariantShimmer,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { AARAV_RATINGS, KIDS, NV_DATE, PARENT, STAFF, THERAPIES, UPI_ID } from '../../data/nuvaraSample'
import { RatingChart } from './charts'
import {
  Avatar,
  Btn,
  Card,
  Chip,
  Divider,
  Greeting,
  Hero,
  HeroOverline,
  HeroPill,
  IconTile,
  IdBadge,
  NV,
  NoteQuote,
  NuvaraScreen,
  RatingPill,
  SectionTitle,
  Sheet,
  TabHeader,
  TrendBadge,
  b,
  d,
  heroDot,
  softShadow,
  tnum,
  toneColors,
  type Tone,
} from './kit'

const aarav = KIDS.aarav

/* ------------------------------------------------------------------ */
/*  Shared parent pieces (lib/screens/parent/kit.dart)                  */
/* ------------------------------------------------------------------ */

/** The family's children as Instagram-style account chips, plus "Add child". */
export function ChildSwitcher({ confirmDot = true }: { confirmDot?: boolean }) {
  return (
    <div className="flex gap-2 overflow-hidden pb-[18px]">
      <span className="flex shrink-0 items-center gap-[9px] rounded-full py-[5px] pl-[5px] pr-3.5" style={{ background: NV.brand900, border: `1px solid ${NV.brand900}`, boxShadow: '0 6px 14px -4px rgba(1,0,57,.2)' }}>
        <Avatar name={aarav.name} size={32} ring />
        <span style={b(14, 700, '#fff')}>{aarav.first}</span>
        <IdBadge code={aarav.code} light />
      </span>
      <span className="flex shrink-0 items-center gap-[9px] rounded-full bg-white py-[5px] pl-[5px] pr-3.5" style={{ border: `1px solid ${NV.line}`, boxShadow: softShadow }}>
        <Avatar name={KIDS.anaya.name} size={32} />
        <span style={b(14, 700)}>{KIDS.anaya.first}</span>
        <IdBadge code={KIDS.anaya.code} />
        {confirmDot && <span className="h-[9px] w-[9px] rounded-full" style={{ background: NV.amber }} />}
      </span>
      <span className="flex shrink-0 items-center gap-2 rounded-full py-1.5 pl-1.5 pr-3.5" style={{ background: NV.canvas, border: `1px solid ${NV.brand300}` }}>
        <span className="flex h-[30px] w-[30px] items-center justify-center rounded-full" style={{ background: NV.brand50 }}>
          <Icon path={mdiPlus} size={18} color={NV.brand700} />
        </span>
        <span style={b(13.5, 700, NV.brand700)}>Add child</span>
      </span>
    </div>
  )
}

/** How one session reads to a parent (Visit in kit.dart). */
const VISIT = {
  upcoming: { label: 'Coming up', tone: 'blue' as Tone, icon: mdiClockOutline },
  live: { label: 'In session now', tone: 'green' as Tone, icon: mdiPlayCircleOutline },
  present: { label: 'Attended', tone: 'green' as Tone, icon: mdiCheckCircle },
  away: { label: 'Away', tone: 'amber' as Tone, icon: mdiCalendarRemoveOutline },
  confirm: { label: 'To confirm', tone: 'amber' as Tone, icon: mdiClockOutline },
  confirmed: { label: 'Confirmed', tone: 'green' as Tone, icon: mdiClockOutline },
}
type VisitKey = keyof typeof VISIT

function TodayRow({ name, time, who, visit, first }: { name: string; time: string; who: string; visit: VisitKey; first?: boolean }) {
  const v = VISIT[visit]
  const c = toneColors[v.tone]
  return (
    <>
      {!first && <Divider indent={16} />}
      <div className="flex items-center gap-3 px-3.5 py-3">
        <span className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-full transition-colors duration-500" style={{ background: c.bg }}>
          <Icon path={v.icon} size={19} color={c.fg} />
        </span>
        <div className="min-w-0 flex-1">
          <span className="block truncate" style={b(14.5, 700)}>
            {name}
          </span>
          <span className="block truncate" style={{ ...b(12.5, 400, NV.muted), ...tnum }}>
            {time} · {who}
          </span>
        </div>
        <Chip tone={v.tone}>{v.label}</Chip>
      </div>
    </>
  )
}

function Grouped({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-hidden rounded-[20px] bg-white" style={{ border: `1px solid ${NV.line}` }}>
      {children}
    </div>
  )
}

/** The therapist's 0–10 report for one session (ProgressRow in widgets/progress.dart). */
export function ProgressRow({ therapy, color, line, rating, note, pending }: { therapy: string; color: string; line: string; rating?: number; note?: string; pending?: boolean }) {
  return (
    <div className="px-4 pb-3.5 pt-3">
      <div className="flex items-center gap-2.5">
        <span className="h-[34px] w-1 shrink-0 rounded-full" style={{ background: color }} />
        <div className="min-w-0 flex-1">
          <span className="block truncate" style={b(14, 700)}>
            {therapy}
          </span>
          <span className="block truncate" style={b(12, 400, NV.muted)}>
            {line}
          </span>
        </div>
        {rating != null ? <RatingPill r={rating} large /> : pending ? <Chip tone="amber">Report pending</Chip> : null}
      </div>
      {note && (
        <div className="mt-2.5 rounded-[14px] px-3 pb-[11px] pt-2.5" style={{ background: NV.brand50, ...b(13.5, 400, NV.ink, 1.45) }}>
          {note}
        </div>
      )}
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Home                                                                 */
/* ------------------------------------------------------------------ */
type HomeProps = {
  /** The family tapped Confirm on the next session. */
  confirmed?: boolean
  /** The therapist has marked the 9:30 session (present). */
  attended?: boolean
  /** The therapist's report for it has arrived. */
  rated?: boolean
  scroll?: number
  overlay?: ReactNode
  network?: 'offline' | 'online'
}

export const AARAV_NOTE = 'Aarav joined in every round of the sound game today and said all his /s/ words clearly. Keep practising the picture cards at home.'

export function ParentHomeScreen({ confirmed, attended, rated, scroll, overlay, network }: HomeProps) {
  return (
    <NuvaraScreen role="parent" tab="home" scroll={scroll} overlay={overlay} network={network} badges={{ schedule: confirmed ? 0 : 1 }}>
      <Greeting name={PARENT.first} avatar={PARENT.name} />
      <ChildSwitcher />
      <NextHero confirmed={confirmed} />
      <div className="h-3" />
      {!confirmed && (
        <Card border="rgba(163,90,0,.45)" className="mb-3.5">
          <div className="flex items-center gap-3">
            <IconTile path={mdiClipboardCheckOutline} color={NV.amber} size={40} />
            <div className="min-w-0 flex-1">
              <span className="block" style={b(14.5, 700)}>
                Confirm Aarav&rsquo;s slots
              </span>
              <span className="block" style={b(12.5, 400, NV.muted, 1.35)}>
                3 sessions planned for this week are waiting for you. The first is today at 11:15 AM.
              </span>
            </div>
            <Icon path={mdiChevronRight} size={24} color={NV.muted} />
          </div>
        </Card>
      )}
      <Card pad={0} border={NV.brand300} style={{ padding: '12px 12px 12px 14px' }}>
        <div className="flex items-center gap-3">
          <IconTile path={mdiMessageBadgeOutline} color={NV.brand700} size={40} />
          <div className="min-w-0 flex-1">
            <span className="block truncate" style={b(14, 700, NV.brand800)}>
              New from the centre · 20m ago
            </span>
            <span className="line-clamp-2 block" style={b(12.5, 400, NV.muted, 1.35)}>
              Diwali break: no sessions from 20 to 22 October. Your new slots will be here by Friday.
            </span>
          </div>
          <span className="rounded-full px-2 py-[3px]" style={{ background: NV.brand700, ...b(11.5, 800, '#fff') }}>
            1
          </span>
        </div>
      </Card>
      <div className="h-[22px]" />
      <SectionTitle title="Today" hint={NV_DATE.long} />
      <Grouped>
        <TodayRow first name="Speech group · Room 1" time="9:30 – 10:15 AM" who={STAFF.rahul.first} visit={attended ? 'present' : 'live'} />
        <TodayRow name="OT · Room 2" time="11:15 AM – 12:00 PM" who={STAFF.priya.first} visit={confirmed ? 'confirmed' : 'confirm'} />
      </Grouped>
      <div className="h-[22px]" />
      <SectionTitle title="Today’s progress" hint={rated ? 'From Aarav’s therapists' : attended ? '1 report still to come' : undefined} />
      <Card pad={0}>
        {attended ? (
          <ProgressRow
            therapy={THERAPIES.speech.name}
            color={THERAPIES.speech.color}
            line={`9:30 – 10:15 AM · Speech group · Room 1 · ${STAFF.rahul.name}`}
            rating={rated ? 8 : undefined}
            pending={!rated}
            note={rated ? AARAV_NOTE : undefined}
          />
        ) : (
          <div className="flex items-center gap-3 p-4">
            <IconTile path={mdiChartTimelineVariantShimmer} size={38} />
            <span style={b(13.5, 600)}>The therapist&rsquo;s report appears here after each session.</span>
          </div>
        )}
      </Card>
    </NuvaraScreen>
  )
}

function NextHero({ confirmed }: { confirmed?: boolean }) {
  return (
    <Hero>
      <div className="flex items-center gap-2">
        <div className="min-w-0 flex-1">
          <HeroOverline>Next session</HeroOverline>
        </div>
        <span className="flex items-center gap-1.5 rounded-full py-[3px] pl-[3px] pr-2.5" style={{ background: 'rgba(255,255,255,.1)' }}>
          <Avatar name={aarav.name} size={22} />
          <span style={b(12, 700, '#fff')}>{aarav.first}</span>
        </span>
      </div>
      <span className="mt-2.5 block" style={{ ...d(28, 500, '#fff'), ...tnum }}>
        Today · 11:15 AM
      </span>
      <span className="mt-1.5 block" style={b(15.5, 600, NV.brand50)}>
        OT · Room 2 with {STAFF.priya.first}
      </span>
      <span className="mt-1 block" style={b(12.5, 600, NV.brand200)}>
        45 min · until 12:00 PM
      </span>
      <div className="mt-[18px]">
        {confirmed ? (
          <div className="flex flex-wrap items-center gap-1">
            <HeroPill dot={heroDot.green}>Confirmed</HeroPill>
            <HeroLink icon={mdiCalendarSync}>Change</HeroLink>
            <HeroLink icon={mdiCalendarRemoveOutline}>Can&rsquo;t make it?</HeroLink>
          </div>
        ) : (
          <>
            {/* Side by side only when both labels fit whole; on a phone they stack. */}
            <div className="flex flex-col gap-2 @[700px]:flex-row">
              <Btn kind="white" icon={mdiCheck} h={44} className="flex-1">
                Confirm
              </Btn>
              <Btn kind="ghostDark" h={44} className="flex-1 !px-2.5">
                Request another slot
              </Btn>
            </div>
            <HeroLink icon={mdiCalendarRemoveOutline}>Can&rsquo;t make it?</HeroLink>
          </>
        )}
      </div>
    </Hero>
  )
}

function HeroLink({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <span className="inline-flex h-9 items-center gap-1.5 px-2" style={b(14, 600, NV.brand100)}>
      <Icon path={icon} size={17} color={NV.brand100} />
      {children}
    </span>
  )
}

/* ------------------------------------------------------------------ */
/*  Schedule                                                             */
/* ------------------------------------------------------------------ */
export function ParentScheduleScreen() {
  return (
    <NuvaraScreen role="parent" tab="schedule">
      <TabHeader title="Schedule" sub="Aarav’s sessions, week by week" />
      <ChildSwitcher />
      <WeekPager label="This week" range={NV_DATE.week} />
      <div className="mt-3.5 flex flex-wrap gap-1.5">
        <Chip dot={false}>6 sessions</Chip>
        <Chip tone="green">2 attended</Chip>
      </div>
      <DayHeading day="Monday" date="5 Oct" />
      <ScheduleTile time="9:30" ampm="AM" name="Speech group · Room 1" span="9:30 – 10:15 AM" who={STAFF.rahul.name} status={<Chip tone="green">Attended</Chip>} rating={7} note="Good focus today. He matched 9 of 10 picture cards on his own." />
      <DayHeading day="Tuesday" date="6 Oct" rel="Today" />
      <ScheduleTile live time="9:30" ampm="AM" name="Speech group · Room 1" span="9:30 – 10:15 AM" who={STAFF.rahul.name} status={<Chip tone="green">In session now</Chip>} />
      <ScheduleTile
        waiting
        time="11:15"
        ampm="AM"
        name="OT · Room 2"
        span="11:15 AM – 12:00 PM"
        who={STAFF.priya.name}
        status={
          <div>
            <div className="flex flex-col gap-2 @[700px]:flex-row">
              <Btn icon={mdiCheck} h={42} className="flex-1">
                Confirm
              </Btn>
              <Btn kind="outlined" h={42} className="flex-1 !px-2" style={{ borderColor: NV.brand300, color: NV.brand800 }}>
                Request another slot
              </Btn>
            </div>
            <span className="mt-1 inline-flex h-9 items-center gap-1.5 px-2" style={b(14, 600, NV.brand700)}>
              <Icon path={mdiCalendarRemoveOutline} size={17} color={NV.brand700} />
              Can&rsquo;t make it?
            </span>
          </div>
        }
      />
    </NuvaraScreen>
  )
}

export function WeekPager({ label, range }: { label: string; range: string }) {
  return (
    <div className="flex items-center rounded-[18px] bg-white" style={{ border: `1px solid ${NV.line}`, boxShadow: softShadow }}>
      <span className="flex h-12 w-12 items-center justify-center">
        <Icon path={mdiChevronLeft} size={24} color={NV.ink} />
      </span>
      <div className="flex-1 py-1.5 text-center">
        <span className="block" style={b(14.5, 700)}>
          {label}
        </span>
        <span className="block" style={{ ...b(12, 400, NV.muted), ...tnum }}>
          {range}
        </span>
      </div>
      <span className="flex h-12 w-12 items-center justify-center">
        <Icon path={mdiChevronRight} size={24} color={NV.ink} />
      </span>
    </div>
  )
}

function DayHeading({ day, date, rel }: { day: string; date: string; rel?: string }) {
  return (
    <div className="flex items-center gap-2 pb-2.5 pl-0.5 pt-3.5">
      <span style={d(18, 500, rel ? NV.brand700 : NV.ink)}>{day}</span>
      <span style={b(13, 600, NV.muted)}>{date}</span>
      {rel && (
        <Chip tone="green" dot={false}>
          {rel}
        </Chip>
      )}
    </div>
  )
}

function ScheduleTile({ time, ampm, name, span, who, status, rating, note, live, waiting }: { time: string; ampm: string; name: string; span: string; who: string; status: ReactNode; rating?: number; note?: string; live?: boolean; waiting?: boolean }) {
  return (
    <Card pad={14} border={live ? NV.brand400 : waiting ? 'rgba(163,90,0,.5)' : NV.line} className="mb-2.5">
      <div className="flex items-start gap-3">
        <div className="w-[62px] shrink-0 rounded-[14px] py-[9px] text-center" style={{ background: live ? NV.brand800 : NV.brand50 }}>
          <span className="block" style={{ ...d(18, 500, live ? '#fff' : NV.brand900), ...tnum }}>
            {time}
          </span>
          <span className="block" style={b(10.5, 700, live ? NV.brand100 : NV.muted)}>
            {ampm}
          </span>
        </div>
        <div className="min-w-0 flex-1">
          <span className="block" style={b(15.5, 700)}>
            {name}
          </span>
          <span className="block" style={{ ...b(12.5, 600, NV.brand700), ...tnum }}>
            {span}
          </span>
          <div className="mt-1 flex items-center gap-[7px]">
            <Avatar name={who} size={20} />
            <span className="truncate" style={b(12.5, 600, NV.muted)}>
              {who}
            </span>
            <span className="shrink-0" style={b(12.5, 400, NV.muted)}>
              · 45 min
            </span>
          </div>
          <div className="mt-2.5">{status}</div>
          {rating != null && (
            <div className="mt-2">
              <RatingPill r={rating} />
            </div>
          )}
          {note && (
            <div className="mt-2.5">
              <NoteQuote>{note}</NoteQuote>
            </div>
          )}
        </div>
      </div>
    </Card>
  )
}

/* ------------------------------------------------------------------ */
/*  Progress                                                             */
/* ------------------------------------------------------------------ */
export function ParentProgressScreen({ grow = 1 }: { grow?: number }) {
  // ProgressSummary: "level lately" is the average of the last 5 reports; the change compares them with the
  // 5 before and needs 6 or more reports. One report (Monday's group session) is still pending.
  const n = Math.max(1, Math.round(grow * AARAV_RATINGS.length))
  const avg = (a: number[]) => a.reduce((x, v) => x + v, 0) / a.length
  const recent = AARAV_RATINGS.slice(Math.max(0, n - 5), n)
  const level = avg(recent)
  const before = AARAV_RATINGS.slice(Math.max(0, n - 10), Math.max(0, n - 5))
  const change = n >= 6 ? level - avg(before) : null
  const band = level >= 7 ? 'Doing well' : level >= 4 ? 'Developing' : 'Needs support'
  const bandTone = level >= 7 ? 'green' : level >= 4 ? 'amber' : 'red'
  const title = change != null && change >= 0.25 ? 'Aarav is moving forward' : `Aarav is ${band.toLowerCase()}`
  const line = [`Average of the last ${Math.min(5, n)} session reports.`, change == null ? '' : Math.abs(change) < 0.25 ? 'Steady lately.' : change > 0 ? `Up ${change.toFixed(1)} on the reports before.` : `Down ${Math.abs(change).toFixed(1)} on the reports before.`]
    .filter(Boolean)
    .join(' ')
  return (
    <NuvaraScreen role="parent" tab="progress">
      <TabHeader title="Progress" sub="How Aarav is growing" />
      <ChildSwitcher />
      <Hero>
        <div className="flex items-center gap-3.5">
          <div className="min-w-0 flex-1">
            <HeroOverline>Progress lately</HeroOverline>
            <span className="mt-1.5 block" style={d(22, 500, '#fff', 1.2)}>
              {title}
            </span>
            <span className="mt-1.5 block" style={b(13, 400, NV.brand100, 1.4)}>
              {line}
            </span>
          </div>
          <div className="flex h-[78px] w-[78px] shrink-0 flex-col items-center justify-center rounded-full" style={{ background: 'rgba(255,255,255,.08)', border: '1.5px solid rgba(255,255,255,.18)' }}>
            <span style={{ ...d(26, 500, '#fff'), ...tnum }}>{level.toFixed(1)}</span>
            <span style={b(10, 700, NV.brand200)}>out of 10</span>
          </div>
        </div>
      </Hero>
      <div className="h-[22px]" />
      <Card pad={0} style={{ padding: '14px 16px 12px' }}>
        <span className="block" style={b(15, 800)}>
          Overall progress
        </span>
        <div className="mt-2.5 grid grid-cols-3">
          <Stat label="Level lately" value={level.toFixed(1)} unit="/10" color={toneColors[bandTone].fg}>
            <Chip tone={bandTone} dot={false}>
              {band}
            </Chip>
          </Stat>
          <Stat label="Change" value={change == null ? '–' : `${change >= 0 ? '+' : '−'}${Math.abs(change).toFixed(1)}`} color={change == null || Math.abs(change) < 0.25 ? NV.ink : change > 0 ? NV.green : NV.amber}>
            {change == null ? <span style={b(11.5, 400, NV.muted)}>Needs 6+ reports</span> : <TrendBadge change={change} />}
          </Stat>
          <Stat label="Reports" value={String(n)} unit={`/${n + 1}`}>
            <Chip tone="amber" dot={false}>
              1 pending
            </Chip>
          </Stat>
        </div>
        <div className="mt-3.5">
          <RatingChart points={AARAV_RATINGS} grow={grow} />
        </div>
        <span className="mt-2 block" style={b(11.5, 400, NV.muted, 1.4)}>
          Each point is one day: the average rating of Aarav&rsquo;s sessions that day, all therapies. Shaded: 7–10 doing well · 4–6 developing · 0–3 needs support.
        </span>
      </Card>
      <div className="h-[22px]" />
      <SectionTitle title="By therapy" />
      <Card pad={0} style={{ padding: '14px 16px 12px' }}>
        <div className="flex items-start gap-2">
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <span className="h-2 w-2 rounded-full" style={{ background: THERAPIES.ot.color }} />
              <span style={b(14.5, 700)}>{THERAPIES.ot.name}</span>
            </div>
            <span className="mt-1 block" style={b(12, 400, NV.muted)}>
              9 reports · level lately 7.6 (doing well)
            </span>
          </div>
          <div className="text-right">
            <span className="block" style={b(10.5, 700, NV.muted)}>
              Latest
            </span>
            <span style={{ ...d(28, 500, THERAPIES.ot.color), ...tnum }}>8</span>
            <span style={b(11.5, 400, NV.muted)}>/10</span>
          </div>
        </div>
      </Card>
    </NuvaraScreen>
  )
}

function Stat({ label, value, unit, color = NV.ink, children }: { label: string; value: string; unit?: string; color?: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <span className="block" style={b(11.5, 700, NV.muted)}>
        {label}
      </span>
      <span className="mt-0.5 block whitespace-nowrap">
        <span style={{ ...d(26, 500, color), ...tnum }}>{value}</span>
        {unit && <span style={b(12, 600, NV.muted)}>{unit}</span>}
      </span>
      <div className="mt-1">{children}</div>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Fees                                                                 */
/* ------------------------------------------------------------------ */
export function ParentFeesScreen({ paid, overlay, scroll }: { paid?: boolean; overlay?: ReactNode; scroll?: number }) {
  return (
    <NuvaraScreen role="parent" tab="fees" overlay={overlay} scroll={scroll}>
      <TabHeader title="Fees" sub="Aarav’s weekly fees" />
      <ChildSwitcher confirmDot={false} />
      <Hero>
        <HeroOverline>{paid ? 'All settled' : 'Due now'}</HeroOverline>
        <span className="mt-2.5 block" style={{ ...d(38, 500, '#fff', 1.05), ...tnum }}>
          {paid ? 'Nothing due' : '₹3,300'}
        </span>
        <span className="mt-1 block" style={b(13.5, 600, NV.brand100)}>
          {paid ? 'Thank you. Every attended session is paid for.' : 'for 1 week · pay any time'}
        </span>
        {!paid && (
          <Btn kind="white" icon={mdiQrcode} className="mt-4">
            Pay with UPI
          </Btn>
        )}
      </Hero>
      <div className="h-6" />
      {paid ? (
        <>
          <SectionTitle title="Payment history" hint="Tap Receipt to download" />
          <Card pad={0}>
            <PaymentTile />
          </Card>
          <div className="h-[18px]" />
          <SectionTitle title="Earlier weeks" />
          <WeekBill paid />
        </>
      ) : (
        <>
          <SectionTitle title="To pay" />
          <WeekBill />
        </>
      )}
      <div className="mt-[18px] flex items-start gap-2">
        <Icon path={mdiStorefrontOutline} size={16} color={NV.muted} className="mt-0.5 shrink-0" />
        <span style={b(12.5, 400, NV.muted, 1.4)}>Paid at the centre? It shows here once recorded, with a receipt.</span>
      </div>
    </NuvaraScreen>
  )
}

function WeekBill({ paid }: { paid?: boolean }) {
  return (
    <Card pad={0} style={{ padding: '14px 16px 16px' }}>
      <span className="block" style={b(15, 700)}>
        {NV_DATE.lastWeek}
      </span>
      <div className="mt-1 flex flex-wrap items-center gap-1.5">
        <Chip tone={paid ? 'green' : 'red'}>{paid ? 'Paid' : 'Due'}</Chip>
        <span style={{ ...b(12, 400, NV.muted), ...tnum }}>5 of 6 attended · ₹3,300</span>
      </div>
      <div className="mt-3 flex pb-1.5" style={{ ...b(10.5, 800, NV.muted), letterSpacing: 0.8 }}>
        <span className="flex-[5]">THERAPY</span>
        <span className="flex-[3] text-center">ATTENDED</span>
        <span className="flex-[4] text-right">AMOUNT</span>
      </div>
      {[
        { t: THERAPIES.ot, a: '3 / 3', amt: '₹2,100' },
        { t: THERAPIES.speech, a: '2 / 3', amt: '₹1,200' },
      ].map((r) => (
        <div key={r.t.name} className="flex items-start py-2" style={{ borderTop: `1px solid ${NV.line}` }}>
          <div className="min-w-0 flex-[5]">
            <div className="flex items-center gap-[7px]">
              <span className="h-2 w-2 shrink-0 rounded-full" style={{ background: r.t.color }} />
              <span className="truncate" style={b(13.5, 700)}>
                {r.t.name}
              </span>
            </div>
            <span className="block pl-[15px]" style={{ ...b(11.5, 400, NV.muted), ...tnum }}>
              ₹{r.t.fee} / session
            </span>
          </div>
          <span className="flex-[3] text-center" style={{ ...b(13.5, 600), ...tnum }}>
            {r.a}
          </span>
          <span className="flex-[4] text-right" style={{ ...b(13.5, 700), ...tnum }}>
            {r.amt}
          </span>
        </div>
      ))}
      <div className="my-2.5 h-px" style={{ background: NV.line }} />
      <Total l="Sessions allocated" v="6" />
      <Total l="Attended (present or late)" v="5" />
      <Total l="Absent · not charged" v="1" />
      <div className="my-2.5 h-px" style={{ background: NV.line }} />
      <Total l="Week total" v="₹3,300" strong />
      {paid && <Total l="Paid" v="− ₹3,300" color={NV.green} />}
      <div className="mt-1.5 flex items-center">
        <span className="flex-1" style={b(15, 800)}>
          Due
        </span>
        <span style={{ ...d(22, 500, paid ? NV.green : NV.clay600), ...tnum }}>{paid ? '₹0' : '₹3,300'}</span>
      </div>
      {!paid && (
        <Btn icon={mdiQrcode} className="mt-3.5">
          Pay ₹3,300 with UPI
        </Btn>
      )}
    </Card>
  )
}

function Total({ l, v, strong, color }: { l: string; v: string; strong?: boolean; color?: string }) {
  return (
    <div className="flex items-center py-[3px]">
      <span className="flex-1" style={b(13, strong ? 800 : 500, strong ? NV.ink : NV.muted)}>
        {l}
      </span>
      <span style={{ ...b(13.5, strong ? 800 : 600, color ?? NV.ink), ...tnum }}>{v}</span>
    </div>
  )
}

function PaymentTile() {
  return (
    <div className="px-3.5 pb-3 pt-3">
      <div className="flex items-center gap-3">
        <span className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-xl" style={{ background: NV.greenBg }}>
          <Icon path={mdiQrcode} size={19} color={NV.green} />
        </span>
        <div className="min-w-0 flex-1">
          <span className="block" style={{ ...b(14.5, 700), ...tnum }}>
            ₹3,300
          </span>
          <span className="block truncate" style={b(12, 400, NV.muted)}>
            Week of 28 Sep · UPI · UTR 627819304512
          </span>
          <span className="block" style={b(11.5, 400, NV.muted)}>
            6 Oct, 9:41 AM
          </span>
        </div>
        <Chip tone="green">Paid · UPI</Chip>
      </div>
      <span className="ml-[42px] mt-1.5 inline-flex h-[34px] items-center gap-1.5 px-2" style={b(14, 600, NV.brand700)}>
        <Icon path={mdiDownload} size={17} color={NV.brand700} />
        Receipt
      </span>
    </div>
  )
}

/** The UPI sheet for a QR payment: the server fixed the amount, payee and reference. */
export function UpiSheet() {
  return (
    <Sheet title="Pay ₹3,300" sub={`${aarav.first} · week of ${NV_DATE.lastWeek}`} footer={[<Btn key="c" kind="outlined" className="flex-1">Cancel</Btn>, <Btn key="p" className="flex-1">I&rsquo;ve paid</Btn>]}>
      <div className="flex items-center gap-4">
        <QrCode />
        <div className="min-w-0 flex-1">
          <span className="block" style={b(11.5, 600, NV.muted)}>
            Pay to
          </span>
          <span className="block" style={b(14.5, 700)}>
            Nuvara Therapy Centre
          </span>
          <span className="block" style={{ ...b(13, 600, NV.brand700), ...tnum }}>
            {UPI_ID}
          </span>
          <span className="mt-2 block" style={b(11.5, 600, NV.muted)}>
            Reference
          </span>
          <span className="block" style={{ ...b(13, 700), ...tnum, letterSpacing: 0.6 }}>
            NVR4Q7K2
          </span>
        </div>
      </div>
      <span className="mt-4 block" style={b(12.5, 400, NV.muted, 1.45)}>
        Pay exactly ₹3,300. Afterwards tap &ldquo;I&rsquo;ve paid&rdquo; and enter the UPI reference number (UTR) from your UPI app.
      </span>
    </Sheet>
  )
}

/** A decorative QR: a stable pseudo-random grid with the three finder squares. */
function QrCode({ size = 132 }: { size?: number }) {
  const n = 25
  const cells: [number, number][] = []
  let s = 7
  for (let y = 0; y < n; y++)
    for (let x = 0; x < n; x++) {
      const finder = (x < 8 && y < 8) || (x > n - 9 && y < 8) || (x < 8 && y > n - 9)
      s = (s * 1103515245 + 12345) & 0x7fffffff
      if (!finder && (s >> 9) % 2) cells.push([x, y])
    }
  const finder = (fx: number, fy: number) => (
    <g key={`${fx}-${fy}`}>
      <rect x={fx} y={fy} width={7} height={7} fill={NV.brand900} />
      <rect x={fx + 1} y={fy + 1} width={5} height={5} fill="#fff" />
      <rect x={fx + 2} y={fy + 2} width={3} height={3} fill={NV.brand900} />
    </g>
  )
  return (
    <span className="shrink-0 rounded-[14px] bg-white p-2" style={{ border: `1px solid ${NV.line}` }}>
      <svg viewBox={`0 0 ${n} ${n}`} width={size} height={size} shapeRendering="crispEdges" aria-hidden>
        {cells.map(([x, y]) => (
          <rect key={`${x}-${y}`} x={x} y={y} width={1} height={1} fill={NV.brand900} />
        ))}
        {finder(0, 0)}
        {finder(n - 7, 0)}
        {finder(0, n - 7)}
      </svg>
    </span>
  )
}

/** "Can't make it?": tell the centre the child will be away. */
export function AwaySheet() {
  const reasons = [
    { l: 'Unwell', p: mdiEmoticonSickOutline },
    { l: 'Doctor’s appointment', p: mdiStethoscope },
    { l: 'Family function', p: mdiPartyPopper },
    { l: 'Travelling', p: mdiBagSuitcaseOutline },
    { l: 'Other', p: mdiNoteEditOutline },
  ]
  return (
    <Sheet title="Can’t make it?" sub="Today, 11:15 AM · OT · Room 2" footer={[<Btn key="c" kind="outlined" className="flex-1">Cancel</Btn>, <Btn key="t" className="flex-[1.4]">Tell the centre</Btn>]}>
      <span className="block" style={b(14, 400, NV.ink, 1.45)}>
        Let the centre know Aarav will be away. Priya will see it straight away, so there is no need to call.
      </span>
      <span className="mt-4 block pb-2.5 uppercase" style={{ ...b(11, 800, NV.muted), letterSpacing: 1.1 }}>
        Reason
      </span>
      <div className="flex flex-wrap gap-2">
        {reasons.map((r, i) => (
          <span key={r.l} className="flex h-10 items-center gap-1.5 rounded-full px-3" style={{ background: i === 0 ? NV.brand800 : '#fff', border: `1px solid ${i === 0 ? NV.brand800 : NV.line}` }}>
            <Icon path={i === 0 ? mdiCheck : r.p} size={16} color={i === 0 ? '#fff' : NV.brand700} />
            <span style={b(13, 600, i === 0 ? '#fff' : NV.ink)}>{r.l}</span>
          </span>
        ))}
      </div>
      <div className="mt-4 rounded-[14px] bg-white px-3.5 py-[13px]" style={{ border: '1px solid #8F94AD', ...b(15, 400) }}>
        Fever since last night
      </div>
    </Sheet>
  )
}

/* ------------------------------------------------------------------ */
/*  Messages                                                             */
/* ------------------------------------------------------------------ */
export function ParentMessagesScreen() {
  return (
    <NuvaraScreen role="parent" tab="messages" badges={{ messages: 0 }}>
      <TabHeader title="Messages" sub="Chat with the centre about Aarav" />
      <div className="mb-2 flex justify-center">
        <span className="rounded-full bg-white px-3 py-1" style={{ border: `1px solid ${NV.line}`, ...b(11.5, 700, NV.muted) }}>
          Today
        </span>
      </div>
      <Bubble>Good morning! Aarav did really well with the new sound cards yesterday. Keep practising the /s/ words at home this week.</Bubble>
      <Bubble time="9:12 AM" mine read>
        Thank you! Could we move Friday&rsquo;s session to the afternoon? His school has a sports day.
      </Bubble>
      <Bubble time="9:20 AM">Of course. Tap &ldquo;Change&rdquo; on Friday&rsquo;s session in Schedule and pick a time, we&rsquo;ll confirm it there.</Bubble>
      <Bubble time="9:24 AM" mine read>
        Done, I&rsquo;ve asked for 3:30 PM.
      </Bubble>
      <div className="absolute inset-x-0 bottom-[92px] flex items-center gap-2 bg-white px-3 py-2.5 @[700px]:bottom-0" style={{ borderTop: `1px solid ${NV.line}` }}>
        <span className="flex h-11 flex-1 items-center rounded-full px-4" style={{ background: NV.canvas, border: `1px solid ${NV.line}`, ...b(14.5, 400, NV.muted) }}>
          Message
        </span>
        <span className="flex h-11 w-11 items-center justify-center rounded-full" style={{ background: NV.brand700 }}>
          <Icon path={mdiSend} size={19} color="#fff" />
        </span>
      </div>
    </NuvaraScreen>
  )
}

function Bubble({ children, mine, time = '8:47 AM', read }: { children: ReactNode; mine?: boolean; time?: string; read?: boolean }) {
  return (
    <div className={`mt-2 flex ${mine ? 'justify-end' : 'justify-start'}`}>
      <div
        className="max-w-[78%] px-[13px] pb-[7px] pt-[9px]"
        style={{
          background: mine ? NV.brand700 : '#fff',
          border: mine ? undefined : `1px solid ${NV.line}`,
          borderRadius: mine ? '18px 18px 6px 18px' : '18px 18px 18px 6px',
          boxShadow: '0 1px 4px rgba(1,0,57,.05)',
        }}
      >
        <span className="block" style={b(14.5, 400, mine ? '#fff' : NV.ink, 1.35)}>
          {children}
        </span>
        <span className="mt-[3px] flex items-center justify-end gap-1">
          <span style={b(10.5, 600, mine ? NV.brand200 : NV.muted)}>{time}</span>
          {mine && <Icon path={read ? mdiCheckAll : mdiCheck} size={14} color={read ? '#7DD3FC' : NV.brand200} />}
        </span>
      </div>
    </div>
  )
}

