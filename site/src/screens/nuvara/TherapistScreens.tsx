import type { ReactNode } from 'react'
import {
  mdiCheck,
  mdiClockOutline,
  mdiClose,
  mdiChevronRight,
  mdiChevronLeft,
  mdiCheckAll,
  mdiLockClock,
  mdiChartTimelineVariantShimmer,
  mdiForumOutline,
  mdiCheckCircle,
  mdiPhone,
  mdiAccountOutline,
  mdiClipboardCheckOutline,
  mdiNoteEditOutline,
  mdiArrowUp,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { KIDS, NV_DATE, STAFF, THERAPIES } from '../../data/nuvaraSample'
import { RatingChart } from './charts'
import { AARAV_NOTE } from './ParentScreens'
import {
  AppBar,
  Avatar,
  Btn,
  Card,
  Chip,
  Divider,
  Greeting,
  Hero,
  HeroDivider,
  HeroStat,
  IconTile,
  IdBadge,
  NV,
  NuvaraScreen,
  RatingPill,
  SectionTitle,
  TabHeader,
  avatarColor,
  b,
  d,
  initials,
  tnum,
  toneColors,
  type Tone,
} from './kit'

const rahul = STAFF.rahul
type Mark = 'present' | 'late' | 'absent' | null

/* ------------------------------------------------------------------ */
/*  Pieces (lib/screens/therapist/parts.dart)                           */
/* ------------------------------------------------------------------ */
export function StatusPill({ label, tone, live, light, icon }: { label: string; tone: Tone; live?: boolean; light?: boolean; icon?: string }) {
  const c = toneColors[tone]
  const fg = light ? '#fff' : c.fg
  return (
    <span className="inline-flex max-w-full items-center rounded-full px-[9px] py-[5px]" style={{ background: light ? 'rgba(255,255,255,.14)' : c.bg }}>
      {icon ? (
        <Icon path={icon} size={13} color={fg} className="mr-1 shrink-0" />
      ) : live ? (
        <span className="mr-1.5 flex h-[11px] w-[11px] shrink-0 items-center justify-center rounded-full" style={{ background: `${light ? '#6EE7B7' : c.fg}40` }}>
          <span className="h-1.5 w-1.5 rounded-full" style={{ background: light ? '#6EE7B7' : c.fg }} />
        </span>
      ) : (
        <span className="mr-1.5 h-1.5 w-1.5 shrink-0 rounded-full" style={{ background: fg }} />
      )}
      <span className="truncate" style={b(11, 700, fg, 1.1)}>
        {label}
      </span>
    </span>
  )
}

const OPTIONS: { v: Exclude<Mark, null>; l: string; p: string; fg: string; bg: string }[] = [
  { v: 'present', l: 'Present', p: mdiCheck, fg: NV.green, bg: NV.greenBg },
  { v: 'late', l: 'Late', p: mdiClockOutline, fg: NV.amber, bg: NV.amberBg },
  { v: 'absent', l: 'Absent', p: mdiClose, fg: NV.red, bg: NV.redBg },
]

/** Present / Late / Absent in one row; tapping the selected option clears it. */
export function AttendanceToggle({ value, enabled = true }: { value: Mark; enabled?: boolean }) {
  return (
    <div className="flex h-[46px] rounded-xl p-[3px]" style={{ background: NV.canvas, border: `1px solid ${NV.line}`, opacity: enabled ? 1 : 0.5 }}>
      {OPTIONS.map((o) => {
        const on = value === o.v
        return (
          <span
            key={o.v}
            className="flex flex-1 items-center justify-center gap-1 rounded-[9px] px-1 transition-colors duration-300"
            style={{ background: on ? o.bg : 'transparent', border: `1px solid ${on ? `${o.fg}59` : 'transparent'}` }}
          >
            <Icon path={o.p} size={15} color={on ? o.fg : NV.muted} />
            <span style={b(12.5, on ? 800 : 600, on ? o.fg : NV.muted)}>{o.l}</span>
          </span>
        )
      })}
    </div>
  )
}

/** A child's place in a session: name + ID, then the attendance toggle. */
export function SeatRow({ name, code, age, mark, enabled = true, pending }: { name: string; code: string; age?: string; mark: Mark; enabled?: boolean; pending?: boolean }) {
  return (
    <div>
      <div className="flex items-center gap-2.5 py-0.5">
        <Avatar name={name} size={30} />
        <div className="min-w-0 flex-1">
          <span className="flex items-center gap-[7px]">
            <span className="truncate" style={b(14.5, 700)}>
              {name}
            </span>
            <IdBadge code={code} />
          </span>
          {age && (
            <span className="block" style={b(12, 400, NV.muted)}>
              {age}
            </span>
          )}
        </div>
        {pending && <Chip tone="amber">Report pending</Chip>}
      </div>
      <div className="mt-2">
        <AttendanceToggle value={mark} enabled={enabled} />
      </div>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Today                                                                */
/* ------------------------------------------------------------------ */
type TodayProps = {
  /** Aarav's and Anaya's marks in the live 9:30 session. */
  aarav?: Mark
  anaya?: Mark
  scroll?: number
}

export function TherapistTodayScreen({ aarav = null, anaya = null, scroll }: TodayProps) {
  const marked = (aarav ? 1 : 0) + (anaya ? 1 : 0)
  const left = 2 - marked
  return (
    <NuvaraScreen role="therapist" tab="today" scroll={scroll}>
      <Greeting name={rahul.first} avatar={rahul.name} />
      <Hero>
        <div className="flex items-center gap-2">
          <span className="min-w-0 flex-1 truncate" style={b(13, 600, NV.brand200)}>
            {NV_DATE.long}
          </span>
          <span className="flex items-center gap-1.5 rounded-full px-2.5 py-[5px]" style={{ background: 'rgba(255,255,255,.1)' }}>
            <span className="h-[7px] w-[7px] rounded-full" style={{ background: '#6EE7B7' }} />
            <span style={b(11, 700, '#fff')}>In session</span>
          </span>
        </div>
        <span className="mt-2 block" style={d(20, 500, '#fff', 1.25)}>
          Now · Speech group · Room 1 until 10:15 AM
        </span>
        <div className="mt-[18px] flex items-center">
          <HeroStat v="3" l="Sessions" />
          <HeroDivider />
          <HeroStat v="4" l="Children" />
          <HeroDivider />
          <HeroStat v={String(left)} l="To mark" />
        </div>
        <span className="mt-4 block h-1.5 overflow-hidden rounded-full" style={{ background: 'rgba(255,255,255,.12)' }}>
          <span className="block h-full rounded-full transition-[width] duration-500" style={{ width: `${(marked / 4) * 100}%`, background: '#6EE7B7' }} />
        </span>
        <span className="mt-1.5 block" style={{ ...b(11.5, 600, NV.brand200), ...tnum }}>
          {marked} of 4 marked
        </span>
      </Hero>
      <div className="h-6" />
      <SectionTitle title="Today’s sessions" hint="Tap a child’s status to mark attendance" />
      <Timeline first live time="9:30 – 10:15 AM" status={<StatusPill label="Live now" tone="green" live />} name="Speech group · Room 1" sub="45 min · 2 children">
        <div className="px-3 pb-3 pt-2.5">
          <SeatRow name={KIDS.aarav.name} code={KIDS.aarav.code} mark={aarav} />
        </div>
        <div className="mx-3.5">
          <Divider />
        </div>
        <div className="px-3 pb-3 pt-2.5">
          <SeatRow name={KIDS.anaya.name} code={KIDS.anaya.code} mark={anaya} />
        </div>
        {left > 0 && (
          <>
            <Divider />
            <div className="px-3 pb-3 pt-2.5">
              <Btn kind="soft" icon={mdiCheckAll}>
                {left === 2 ? 'Mark all present' : 'Mark the rest present'}
              </Btn>
            </div>
          </>
        )}
      </Timeline>
      <Timeline next time="10:15 – 11:00 AM" status={<StatusPill label="Next" tone="blue" />} name="Speech · Room 1" sub="45 min · 1 child">
        <div className="px-3 pb-3 pt-2.5">
          <SeatRow name={KIDS.diya.name} code={KIDS.diya.code} mark={null} enabled={false} />
        </div>
        <div className="flex items-center gap-1.5 px-3.5 pb-3">
          <Icon path={mdiLockClock} size={14} color={NV.blue} />
          <span style={b(12, 600, NV.blue)}>Attendance opens at 10:00 AM</span>
        </div>
      </Timeline>
      <Timeline last time="3:30 – 4:15 PM" status={<StatusPill label="Later" tone="neutral" />} name="Speech · Room 1" sub="45 min · 1 child" />
    </NuvaraScreen>
  )
}

function Timeline({ children, time, status, name, sub, live, next, first, last }: { children?: ReactNode; time: string; status: ReactNode; name: string; sub: string; live?: boolean; next?: boolean; first?: boolean; last?: boolean }) {
  const dot = live ? NV.green : next ? NV.blue : NV.line
  return (
    <div className="relative pb-3.5 pl-6">
      <span className="absolute left-1.5 w-0.5" style={{ top: first ? 22 : 0, bottom: last ? undefined : 0, height: last ? 22 : undefined, background: NV.line }} />
      <span
        className="absolute left-0 top-4 h-3.5 w-3.5 rounded-full"
        style={{ background: dot === NV.line ? '#fff' : dot, border: `2.5px solid ${dot === NV.line ? 'rgba(98,102,127,.4)' : '#fff'}`, boxShadow: live ? '0 0 8px rgba(16,116,67,.35)' : undefined }}
      />
      <Card pad={0} radius={22} border={live ? NV.brand400 : NV.line}>
        <div className="px-3.5 pb-2.5 pt-3">
          <div className="flex items-center gap-2">
            <span className="rounded-[9px] px-[9px] py-[5px]" style={{ background: live ? NV.brand800 : NV.brand50, ...b(12, 800, live ? '#fff' : NV.brand800), ...tnum }}>
              {time}
            </span>
            <span className="flex flex-1 justify-end">{status}</span>
          </div>
          <div className="mt-[9px] flex items-center">
            <span className="flex-1 truncate" style={d(19)}>
              {name}
            </span>
            <Icon path={mdiChevronRight} size={20} color={NV.muted} />
          </div>
          <span className="block" style={b(12.5, 400, NV.muted)}>
            {sub}
          </span>
        </div>
        {children && <Divider />}
        {children}
      </Card>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  One session: attendance, then a 0–10 rating and a note per child    */
/* ------------------------------------------------------------------ */
type SessionProps = {
  rating?: number | null
  /** 0–1: how much of the description for parents has been written. */
  typed?: number
  scroll?: number
}

export function TherapistSessionScreen({ rating = 8, typed = 1, scroll }: SessionProps) {
  const note = AARAV_NOTE.slice(0, Math.round(AARAV_NOTE.length * typed))
  const saved = typed >= 1
  return (
    <NuvaraScreen role="therapist" bar={<AppBar title="Today" />} scroll={scroll}>
      <Hero>
        <div className="flex items-center gap-2">
          <span className="min-w-0 flex-1 truncate" style={b(13, 600, NV.brand200)}>
            {NV_DATE.long}
          </span>
          <StatusPill label="Live now" tone="green" live light />
        </div>
        <span className="mt-2 block" style={d(26, 500, '#fff')}>
          Speech group · Room 1
        </span>
        <span className="mt-1 block" style={{ ...b(13.5, 600, 'rgba(255,255,255,.85)'), ...tnum }}>
          9:30 – 10:15 AM · 45 min
        </span>
        <div className="mt-[18px] flex items-center">
          <HeroStat v="2" l="Present" />
          <HeroDivider />
          <HeroStat v="0" l="Late" />
          <HeroDivider />
          <HeroStat v="0" l="Absent" />
          <HeroDivider />
          <HeroStat v="0" l="To mark" />
        </div>
      </Hero>
      <div className="h-4" />
      <SectionTitle title="Children" hint="Ratings and descriptions are shared with parents" />
      <Card pad={14} radius={22}>
        <SeatRow name={KIDS.aarav.name} code={KIDS.aarav.code} age={KIDS.aarav.age} mark="present" pending={rating == null} />
        <div className="mt-4 flex items-center gap-1.5">
          <Icon path={mdiChartTimelineVariantShimmer} size={16} color={NV.muted} />
          <span className="flex-1" style={b(13, 700)}>
            {THERAPIES.speech.name} rating
          </span>
          {rating != null ? <RatingPill r={rating} /> : <Chip tone="amber">Report pending</Chip>}
        </div>
        <RatingRow value={rating} />
        <div className="mt-1 flex justify-between" style={b(10.5, 400, NV.muted)}>
          <span>Needs a lot of help</span>
          <span>Did brilliantly</span>
        </div>
        <div className="mt-3.5 flex items-center gap-1.5">
          <Icon path={mdiForumOutline} size={16} color={NV.muted} />
          <span className="flex-1" style={b(13, 700)}>
            Description for parents
          </span>
          {note && (
            <span className="flex items-center gap-1" style={b(11.5, 700, saved ? NV.green : NV.muted)}>
              <Icon path={saved ? mdiCheckCircle : mdiNoteEditOutline} size={14} color={saved ? NV.green : NV.muted} />
              {saved ? 'Saved' : 'Editing'}
            </span>
          )}
        </div>
        <div className="mt-2 min-h-[66px] rounded-[14px] bg-white px-3.5 py-3" style={{ border: `${saved ? 1 : 1.6}px solid ${saved ? '#8F94AD' : NV.brand600}`, ...b(14.5, 400, note ? NV.ink : NV.muted, 1.4) }}>
          {note || 'How did the session go? Parents read this with the rating.'}
          {!saved && note && <span className="ml-px inline-block h-[17px] w-[1.5px] translate-y-[3px] animate-pulse" style={{ background: NV.brand600 }} />}
        </div>
      </Card>
      <div className="h-3" />
      <Card pad={14} radius={22}>
        <SeatRow name={KIDS.anaya.name} code={KIDS.anaya.code} age={KIDS.anaya.age} mark="present" pending />
      </Card>
    </NuvaraScreen>
  )
}

/** One row of 11 equal cells, 0–10; cells below the pick are tinted in its colour band. */
export function RatingRow({ value }: { value: number | null | undefined }) {
  const band = (r: number) => (r >= 7 ? NV.green : r >= 4 ? NV.amber : NV.red)
  return (
    <div className="mt-2 flex gap-[3px]">
      {Array.from({ length: 11 }, (_, i) => {
        const on = value === i
        const below = value != null && i < value
        return (
          <span
            key={i}
            className="flex h-11 flex-1 items-center justify-center rounded-[9px] transition-colors duration-300"
            style={{ background: on ? band(i) : below ? `${band(value!)}1f` : NV.canvas, border: `1px solid ${on ? band(i) : NV.line}`, ...b(13, 800, on ? '#fff' : NV.ink), ...tnum }}
          >
            {i}
          </span>
        )
      })}
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  My week                                                              */
/* ------------------------------------------------------------------ */
export function TherapistWeekScreen() {
  return (
    <NuvaraScreen role="therapist" tab="week">
      <TabHeader title="My week" />
      <div className="flex items-center rounded-[18px] bg-white" style={{ border: `1px solid ${NV.line}` }}>
        <span className="flex h-12 w-12 items-center justify-center">
          <Icon path={mdiChevronLeft} size={24} color={NV.ink} />
        </span>
        <div className="flex-1 py-1.5 text-center">
          <span className="block" style={b(14.5, 700)}>
            This week
          </span>
          <span className="block" style={b(12, 400, NV.muted)}>
            {NV_DATE.week}
          </span>
        </div>
        <span className="flex h-12 w-12 items-center justify-center">
          <Icon path={mdiChevronRight} size={24} color={NV.ink} />
        </span>
      </div>
      <div className="h-3" />
      <Hero pad="14px 6px">
        <div className="flex items-center">
          <HeroStat v="14" l="Sessions" />
          <HeroDivider />
          <HeroStat v="9" l="Children" />
          <HeroDivider />
          <HeroStat v="10.5h" l="Hours" />
          <HeroDivider />
          <HeroStat v="2" l="To mark" />
        </div>
      </Hero>
      <div className="h-[18px]" />
      <DayGroup day="Monday, 5 Oct" count="3 sessions">
        <WeekRow first t="9:30" a="AM" name="Speech group · Room 1" kids="Aarav C001 · Anaya C002" status={<StatusPill label="Completed · all present" tone="green" icon={mdiCheck} />} />
        <WeekRow t="10:15" a="AM" name="Speech · Room 1" kids="Diya C003" status={<StatusPill label="Completed · all present" tone="green" icon={mdiCheck} />} />
        <WeekRow t="3:30" a="PM" name="Speech · Room 1" kids="Meher C007" status={<StatusPill label="Report pending" tone="amber" icon={mdiNoteEditOutline} />} />
      </DayGroup>
      <DayGroup day="Tuesday, 6 Oct" count="3 sessions" today>
        <WeekRow first live t="9:30" a="AM" name="Speech group · Room 1" kids="Aarav C001 · Anaya C002" status={<StatusPill label="Live now" tone="green" live />} />
        <WeekRow t="10:15" a="AM" name="Speech · Room 1" kids="Diya C003" status={<StatusPill label="Next" tone="blue" />} />
        <WeekRow t="3:30" a="PM" name="Speech · Room 1" kids="Meher C007" status={<StatusPill label="Later" tone="neutral" />} extra={<Chip tone="amber">1 away</Chip>} />
      </DayGroup>
    </NuvaraScreen>
  )
}

function DayGroup({ day, count, today, children }: { day: string; count: string; today?: boolean; children: ReactNode }) {
  return (
    <div className="pb-4">
      <div className="flex items-center gap-2 px-1 pb-2">
        <span style={b(14, 800, today ? NV.brand700 : NV.ink)}>{day}</span>
        {today && (
          <Chip tone="green" dot={false}>
            Today
          </Chip>
        )}
        <span className="flex-1" />
        <span style={b(12, 400, NV.muted)}>{count}</span>
      </div>
      <div className="overflow-hidden rounded-[20px] bg-white" style={{ border: `1px solid ${NV.line}` }}>
        {children}
      </div>
    </div>
  )
}

function WeekRow({ t, a, name, kids, status, extra, first, live }: { t: string; a: string; name: string; kids: string; status: ReactNode; extra?: ReactNode; first?: boolean; live?: boolean }) {
  return (
    <>
      {!first && <Divider indent={76} />}
      <div className="flex items-center gap-3 py-3 pl-3.5 pr-2">
        <div className="w-[50px] shrink-0 rounded-xl py-1.5 text-center" style={{ background: live ? NV.brand800 : NV.brand50 }}>
          <span className="block" style={{ ...d(16, 500, live ? '#fff' : NV.brand900), ...tnum }}>
            {t}
          </span>
          <span className="block" style={b(10, 700, live ? NV.brand100 : NV.muted)}>
            {a}
          </span>
        </div>
        <div className="min-w-0 flex-1">
          <span className="block truncate" style={b(14.5, 700)}>
            {name}
          </span>
          <span className="block truncate" style={b(12, 600, NV.muted)}>
            {kids}
          </span>
          <div className="mt-1.5 flex flex-wrap gap-1.5">
            {status}
            {extra}
          </div>
        </div>
        <Icon path={mdiChevronRight} size={20} color={NV.muted} />
      </div>
    </>
  )
}

/* ------------------------------------------------------------------ */
/*  A child: family, assessments, progress                              */
/* ------------------------------------------------------------------ */
export function TherapistChildScreen() {
  const c = KIDS.aarav
  const base = avatarColor(c.name)
  return (
    <NuvaraScreen role="therapist" bar={<AppBar title={c.code} />}>
      <div className="flex items-center gap-4 rounded-[26px] p-5" style={{ background: `linear-gradient(135deg, ${base}, #4a2c70)`, boxShadow: `0 12px 24px -8px ${base}4d` }}>
        <span className="flex h-[62px] w-[62px] shrink-0 items-center justify-center rounded-full" style={{ background: 'rgba(255,255,255,.16)', border: '1.5px solid rgba(255,255,255,.3)', ...d(23, 500, '#fff') }}>
          {initials(c.name)}
        </span>
        <div className="min-w-0">
          <span className="block" style={d(23, 500, '#fff')}>
            {c.name}
          </span>
          <span className="mt-1.5 flex items-center gap-2">
            <IdBadge code={c.code} light />
            <span style={b(13, 600, 'rgba(255,255,255,.9)')}>{c.age}</span>
          </span>
        </div>
      </div>
      <div className="h-3.5" />
      <Card>
        <span className="block pb-2.5 uppercase" style={{ ...b(11, 800, NV.muted), letterSpacing: 1.1 }}>
          Parents
        </span>
        <div className="grid grid-cols-2 gap-2.5">
          <KV label="Father" value="Vikram Sharma" />
          <KV label="Mother" value="Neha Sharma" />
        </div>
        <div className="mt-3.5 flex items-center gap-3 rounded-[14px] py-2.5 pl-3 pr-3.5" style={{ background: NV.greenBg }}>
          <span className="flex h-9 w-9 items-center justify-center rounded-full" style={{ background: NV.green }}>
            <Icon path={mdiPhone} size={18} color="#fff" />
          </span>
          <div className="flex-1">
            <span className="block" style={b(11.5, 600, NV.green)}>
              Main number
            </span>
            <span className="block" style={{ ...b(15, 700), ...tnum }}>
              +91 98765 43210
            </span>
          </div>
          <span style={b(13, 800, NV.green)}>Call</span>
        </div>
      </Card>
      <div className="h-[26px]" />
      <SectionTitle title="Assessments" hint="Pediatric OT assessment" action="+ New assessment" />
      <Card pad={0}>
        <HistoryRow kind="Re-assessment" meta={`1 Oct 2026 · ${STAFF.priya.name}`} />
        <Divider indent={70} />
        <HistoryRow kind="Initial assessment" meta={`2 Jul 2026 · ${STAFF.priya.name}`} />
      </Card>
      <div className="h-[22px]" />
      <AssessmentProgressCard />
      <div className="h-[22px]" />
      <SectionTitle title="Progress" hint="Session ratings from every therapist" />
      <Card pad={0} style={{ padding: '14px 16px 12px' }}>
        <div className="flex items-center gap-2">
          <span className="h-2 w-2 rounded-full" style={{ background: THERAPIES.speech.color }} />
          <span className="flex-1" style={b(14.5, 700)}>
            {THERAPIES.speech.name}
          </span>
          <RatingPill r={8} />
        </div>
        <div className="mt-2.5">
          <RatingChart points={[4, 5, 4.5, 5.5, 6, 6, 7, 6.5, 7, 8]} color={THERAPIES.speech.color} height={130} />
        </div>
      </Card>
    </NuvaraScreen>
  )
}

function KV({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start gap-3">
      <span className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[10px]" style={{ background: NV.canvas }}>
        <Icon path={mdiAccountOutline} size={17} color={NV.brand700} />
      </span>
      <div className="min-w-0">
        <span className="block" style={b(11.5, 600, NV.muted)}>
          {label}
        </span>
        <span className="block truncate" style={b(14.5, 600)}>
          {value}
        </span>
      </div>
    </div>
  )
}

function HistoryRow({ kind, meta }: { kind: string; meta: string }) {
  return (
    <div className="flex items-center gap-3.5 py-[13px] pl-4 pr-2.5">
      <IconTile path={mdiClipboardCheckOutline} color={NV.green} size={40} />
      <div className="min-w-0 flex-1">
        <span className="block" style={b(14.5, 700)}>
          {kind}
        </span>
        <span className="block truncate" style={b(12.5, 600, 'rgba(13,14,44,.75)')}>
          {meta}
        </span>
      </div>
      <Chip tone="green">Completed</Chip>
      <Icon path={mdiChevronRight} size={22} color={NV.muted} />
    </div>
  )
}

const AREAS = [
  { l: 'Sensory', e: 9, dv: 3, n: 1, delta: 4 },
  { l: 'Hand Function', e: 11, dv: 4, n: 1, delta: 3 },
  { l: 'ADL', e: 8, dv: 3, n: 2, delta: 2 },
  { l: 'Play', e: 5, dv: 1, n: 0, delta: 2 },
  { l: 'Behaviour', e: 10, dv: 2, n: 1, delta: 1 },
]

/** AssessmentProgressCard: the latest OT assessment as a plain count, then each area split into three levels. */
export function AssessmentProgressCard({ grow = 1 }: { grow?: number }) {
  return (
    <>
      <SectionTitle title="Assessment progress" hint="From 2 completed assessments" />
      <Card pad={0} style={{ padding: '16px 16px 12px' }}>
        <div className="flex flex-wrap items-end gap-x-2.5 gap-y-1">
          <span style={{ ...d(34), ...tnum }}>{Math.round(48 + 24 * grow)}%</span>
          <span className="pb-1.5" style={b(13, 700)}>
            at the expected level
          </span>
          <span className="mb-1.5 inline-flex items-center gap-0.5 rounded-full px-2 py-[3px]" style={{ background: NV.greenBg, ...b(11.5, 800, NV.green) }}>
            <Icon path={mdiArrowUp} size={13} color={NV.green} />
            {Math.round(24 * grow)} points
          </span>
        </div>
        <span className="mt-0.5 block" style={b(12, 400, NV.muted, 1.35)}>
          52 of 72 assessed items · Re-assessment, 1 Oct 2026 · compared with 2 Jul 2026
        </span>
        <span className="mb-1.5 mt-3.5 block" style={b(13, 800)}>
          Latest by area
        </span>
        {AREAS.map((a) => {
          const total = a.e + a.dv + a.n
          return (
            <div key={a.l} className="flex items-center gap-1 py-1.5">
              <span className="w-[104px] shrink-0 truncate" style={b(12.5, 600)}>
                {a.l}
              </span>
              <div className="flex h-3 flex-1 gap-0.5">
                <span className="rounded" style={{ flex: a.e * grow + 0.001, background: NV.green, transition: 'flex .5s' }} />
                <span className="rounded" style={{ flex: a.dv + a.e * (1 - grow), background: '#E3A23B', transition: 'flex .5s' }} />
                {a.n > 0 && <span className="rounded" style={{ flex: a.n, background: '#E46A6A' }} />}
              </div>
              <span className="w-10 text-right" style={{ ...b(12, 800), ...tnum }}>
                {Math.round(a.e * grow)}/{total}
              </span>
              <span className="w-12 text-right" style={b(11, 700, NV.green)}>
                +{Math.round(((a.delta * 100) / total) * grow)}
              </span>
            </div>
          )
        })}
      </Card>
    </>
  )
}

