import type { ReactNode } from 'react'
import {
  mdiArrowRight,
  mdiArrowTopRight,
  mdiCalendarSync,
  mdiChevronRight,
  mdiChevronLeft,
  mdiChatOutline,
  mdiNoteEditOutline,
  mdiClipboardCheckOutline,
  mdiCalendarRemoveOutline,
  mdiWallet,
  mdiHeart,
  mdiCalendarWeek,
  mdiBabyFace,
  mdiCardAccountDetails,
  mdiQrcode,
  mdiDotsVertical,
  mdiClockOutline,
  mdiAccountGroupOutline,
  mdiViewGridOutline,
  mdiViewAgendaOutline,
  mdiPlus,
  mdiMagnify,
  mdiLockOutline,
  mdiHumanMaleChild,
  mdiCheck,
  mdiCheckCircle,
  mdiArrowLeft,
  mdiContentSaveOutline,
  mdiCloudCheckOutline,
  mdiNoteTextOutline,
  mdiCalendarBlankOutline,
  mdiAccountOutline,
  mdiShapeOutline,
  mdiClipboardTextOutline,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { ADMIN, KIDS, NV_DATE, STAFF, THERAPIES } from '../../data/nuvaraSample'
import { AssessmentProgressCard } from './TherapistScreens'
import {
  AppBar,
  Avatar,
  AvatarStack,
  Bar,
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
  NuvaraMark,
  NuvaraScreen,
  SectionTitle,
  Segmented,
  StatusBar,
  TabHeader,
  avatarColor,
  b,
  d,
  initials,
  softShadow,
  tnum,
} from './kit'

/* ------------------------------------------------------------------ */
/*  Home                                                                 */
/* ------------------------------------------------------------------ */
type Attention = { icon: string; color: string; title: string; sub: string }

const ATTENTION: Attention[] = [
  { icon: mdiChatOutline, color: NV.brand600, title: '1 unread message from a family', sub: 'From Diya' },
  { icon: mdiNoteEditOutline, color: NV.amber, title: '2 session reports pending', sub: 'From Rahul, Kumar · oldest yesterday' },
  { icon: mdiClipboardCheckOutline, color: NV.blue, title: 'Verify a payment of ₹3,300', sub: 'Check them against the centre’s bank or UPI app' },
  { icon: mdiCalendarRemoveOutline, color: NV.amber, title: 'Meher away', sub: 'Today 3:30 PM · Speech · Room 1 · Fever since last night' },
  { icon: mdiWallet, color: NV.red, title: 'Kavin has an unpaid earlier week', sub: '₹2,400 overdue · C004' },
]

/** `focus` highlights one "Needs attention" row (a family's action arriving); 99 highlights the slot-request card. */
export function AdminHomeScreen({ focus = -1, requests = 1, scroll }: { focus?: number; requests?: number; scroll?: number }) {
  return (
    <NuvaraScreen role="admin" tab="home" scroll={scroll}>
      <Greeting name={ADMIN.first} avatar={ADMIN.name} />
      <Hero>
        <div className="flex items-center gap-2">
          <span className="flex-1" style={b(13, 600, NV.brand200)}>
            {NV_DATE.long}
          </span>
          <span className="flex items-center gap-1.5 rounded-full px-2.5 py-[5px]" style={{ background: 'rgba(255,255,255,.1)' }}>
            <span className="h-[7px] w-[7px] rounded-full" style={{ background: '#6EE7B7' }} />
            <span style={b(11, 700, '#fff')}>In session</span>
          </span>
        </div>
        <span className="mt-2 block" style={d(19, 500, '#fff', 1.25)}>
          Now · 9:30 – 10:15 AM · 4 sessions
        </span>
        <div className="mt-[18px] flex items-center">
          <HeroStat v="5" l="Slots" />
          <HeroDivider />
          <HeroStat v="14" l="Sessions" />
          <HeroDivider />
          <HeroStat v="11" l="Children" />
          <HeroDivider />
          <HeroStat v="4" l="Therapists" />
        </div>
        <div className="mt-4 h-px" style={{ background: 'rgba(255,255,255,.12)' }} />
        <div className="mt-3 flex flex-wrap items-center gap-1.5">
          <span className="mr-0.5" style={b(12, 700, NV.brand200)}>
            Attendance
          </span>
          <HeroDotPill dot="#6EE7B7">5 present</HeroDotPill>
          <HeroDotPill dot="#FCD34D">1 late</HeroDotPill>
          <HeroDotPill dot="#FCA5A5">0 absent</HeroDotPill>
          <HeroDotPill dot="rgba(255,255,255,.5)">2 to mark</HeroDotPill>
          <HeroDotPill dot="#F59E0B">1 away</HeroDotPill>
        </div>
      </Hero>
      {requests > 0 && (
        <>
          <div className="h-[22px]" />
          <RequestsAlert highlight={focus === 99} />
        </>
      )}
      <div className="h-[22px]" />
      <div className="mb-2.5 flex items-center gap-2">
        <span style={d(19)}>Needs attention</span>
        <span className="rounded-full px-2 py-0.5" style={{ background: NV.clay600, ...b(11.5, 800, '#fff'), ...tnum }}>
          {ATTENTION.length}
        </span>
      </div>
      <Card pad={0}>
        {ATTENTION.map((a, i) => (
          <div key={a.title}>
            {i > 0 && <Divider indent={64} />}
            <div className="flex items-center gap-3 py-3 pl-3.5 pr-2.5 transition-colors duration-500" style={{ background: i === focus ? NV.brand50 : 'transparent' }}>
              <IconTile path={a.icon} color={a.color} size={38} />
              <div className="min-w-0 flex-1">
                <span className="block truncate" style={b(14, 700)}>
                  {a.title}
                </span>
                <span className="mt-0.5 block truncate" style={b(12.5, 400, NV.muted, 1.35)}>
                  {a.sub}
                </span>
              </div>
              <Icon path={mdiChevronRight} size={20} color={NV.muted} />
            </div>
          </div>
        ))}
      </Card>
      <div className="h-[22px]" />
      <div className="grid grid-cols-2 gap-2.5 @[700px]:grid-cols-3">
        <NavCard icon={mdiHeart} color="#B8486A" title="Our therapies" value="5 therapies" />
        <NavCard icon={mdiCalendarWeek} color={NV.brand600} title="Timetables" value="35 slots this week" />
        <NavCard icon={mdiBabyFace} color="#C2622D" title="Children" value="24 enrolled" />
        <NavCard icon={mdiCardAccountDetails} color="#3D64A8" title="Therapists" value="4 on staff" />
        <NavCard icon={mdiCalendarSync} color={NV.violet} title="Slot requests" value={requests ? `${requests} waiting` : 'None waiting'} />
        <NavCard icon={mdiQrcode} color="#2B8A9A" title="Payments" value="1 to verify" />
      </div>
    </NuvaraScreen>
  )
}

function HeroDotPill({ dot, children }: { dot: string; children: ReactNode }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full px-[9px] py-1" style={{ background: 'rgba(255,255,255,.1)' }}>
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: dot }} />
      <span style={{ ...b(11.5, 700, '#fff'), ...tnum }}>{children}</span>
    </span>
  )
}

function NavCard({ icon, color, title, value }: { icon: string; color: string; title: string; value: string }) {
  return (
    <Card pad={14} className="flex h-[118px] flex-col">
      <div className="flex items-center">
        <IconTile path={icon} color={color} size={36} />
        <span className="flex-1" />
        <Icon path={mdiArrowTopRight} size={16} color="rgba(98,102,127,.6)" />
      </div>
      <span className="flex-1" />
      <span className="block truncate" style={b(14.5, 700)}>
        {title}
      </span>
      <span className="block truncate" style={b(12, 400, NV.muted)}>
        {value}
      </span>
    </Card>
  )
}

/** Families asking for another slot get their own violet card, above "Needs attention". */
function RequestsAlert({ highlight }: { highlight?: boolean }) {
  return (
    <div
      className="overflow-hidden rounded-[22px] transition-shadow duration-500"
      style={{ background: NV.violetBg, border: `1.5px solid ${NV.violet}8c`, boxShadow: highlight ? `0 0 0 4px ${NV.violet}40, 0 10px 28px ${NV.violet}55` : `0 6px 20px ${NV.violet}29` }}
    >
      <div className="flex items-center gap-3 px-4 py-3.5" style={{ background: NV.violet }}>
        <Icon path={mdiCalendarSync} size={24} color="#fff" />
        <div className="min-w-0 flex-1">
          <span className="block truncate" style={b(15.5, 800, '#fff')}>
            A family needs another slot
          </span>
          <span className="block truncate" style={b(12, 600, 'rgba(255,255,255,.85)')}>
            Answer before the session · soonest Fri, 9 Oct
          </span>
        </div>
        <span className="rounded-full bg-white px-[9px] py-[3px]" style={{ ...b(12.5, 800, NV.violet), ...tnum }}>
          1
        </span>
      </div>
      <div className="flex items-center gap-3 py-3 pl-3.5 pr-2.5">
        <Avatar name={KIDS.aarav.name} size={36} />
        <div className="min-w-0 flex-1">
          <span className="block truncate" style={b(14, 700)}>
            Aarav · this day only
          </span>
          <span className="mt-0.5 block truncate" style={b(12.5, 400, NV.muted)}>
            Can&rsquo;t make Fri, 9 Oct 11:15 AM · OT · Room 2
          </span>
          <span className="block truncate" style={b(12.5, 700, NV.violet)}>
            Asks for: Fri, 9 Oct · 3:30 – 4:15 PM
          </span>
        </div>
        <Icon path={mdiChevronRight} size={22} color={`${NV.violet}b3`} />
      </div>
      <div className="px-3.5 pb-3.5 pt-1.5">
        <Btn icon={mdiArrowRight} h={44} style={{ background: NV.violet }}>
          Review request
        </Btn>
      </div>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Timetable: one week as a grid of days × time slots                  */
/* ------------------------------------------------------------------ */
const COLS = [
  { s: '9:30', e: '10:15 AM', m: 45 },
  { s: '10:15', e: '11:00 AM', m: 45 },
  { s: '11:15', e: '12:00 PM', m: 45 },
  { s: '2:00', e: '2:45 PM', m: 45 },
  { s: '3:30', e: '4:15 PM', m: 45 },
  { s: '4:15', e: '5:00 PM', m: 45 },
]
const DAYS = [
  { k: 'MON', n: 5 },
  { k: 'TUE', n: 6, today: true },
  { k: 'WED', n: 7 },
  { k: 'THU', n: 8 },
  { k: 'FRI', n: 9 },
  { k: 'SAT', n: 10 },
  { k: 'SUN', n: 11 },
]
/** Sessions per cell (0 = no slot). Saturday is half a day, Sunday off. */
const GRID = [
  [4, 3, 2, 2, 3, 1],
  [4, 3, 2, 2, 3, 0],
  [3, 3, 2, 1, 2, 1],
  [4, 2, 3, 2, 3, 1],
  [3, 3, 2, 2, 4, 0],
  [2, 2, 1, 0, 0, 0],
  [0, 0, 0, 0, 0, 0],
]
const PEOPLE = [STAFF.rahul.name, STAFF.priya.name, STAFF.divya.name, STAFF.kumar.name]

export function AdminTimetableScreen({ added = 0 }: { added?: number }) {
  const max = 4
  return (
    <NuvaraScreen
      role="admin"
      wide={false}
      bar={
        <div className="absolute inset-x-0 top-0 z-20 flex h-14 items-center px-1" style={{ background: NV.canvas }}>
          <span className="flex h-10 w-10 items-center justify-center">
            <Icon path={mdiArrowLeft} size={22} color={NV.ink} />
          </span>
          <span className="flex h-10 w-10 items-center justify-center">
            <Icon path={mdiChevronLeft} size={24} color={NV.ink} />
          </span>
          <div className="flex-1 text-center">
            <span className="block" style={b(15.5, 700)}>
              This week
            </span>
            <span className="block" style={b(12, 400, NV.muted)}>
              {NV_DATE.week}
            </span>
          </div>
          <span className="flex h-10 w-10 items-center justify-center">
            <Icon path={mdiChevronRight} size={24} color={NV.ink} />
          </span>
          <span className="flex h-10 w-10 items-center justify-center">
            <Icon path={mdiDotsVertical} size={22} color={NV.ink} />
          </span>
        </div>
      }
    >
      <div className="mx-auto max-w-[760px]">
        <div className="grid grid-cols-3 gap-2">
          <MiniStat v="31" l="Slots" icon={mdiClockOutline} />
          <MiniStat v={String(70 + added)} l="Sessions" icon={mdiAccountGroupOutline} />
          <MiniStat v="24" l="Children" icon={mdiHumanMaleChild} />
        </div>
        <div className="mt-3.5">
          <Segmented
            expand
            value={0}
            options={[
              { label: 'Grid view', icon: mdiViewGridOutline },
              { label: 'Day view', icon: mdiViewAgendaOutline },
            ]}
          />
        </div>
      </div>
      <div className="mt-4 flex overflow-hidden rounded-[22px] bg-white" style={{ border: `1px solid ${NV.line}`, boxShadow: softShadow }}>
        <div className="w-[70px] shrink-0" style={{ background: NV.canvas, borderRight: `1px solid ${NV.line}` }}>
          <div className="flex h-[78px] items-center justify-center" style={{ ...b(10, 800, NV.muted), letterSpacing: 1.2 }}>
            DAY
          </div>
          {DAYS.map((dd) => (
            <div key={dd.k} className="flex h-[96px] flex-col items-center justify-center" style={{ borderTop: `1px solid ${NV.line}` }}>
              <span style={{ ...b(10.5, 800, dd.today ? NV.brand700 : NV.muted), letterSpacing: 0.8 }}>{dd.k}</span>
              <span className="mt-1 flex h-[34px] w-[34px] items-center justify-center rounded-full" style={{ background: dd.today ? NV.brand700 : 'transparent', ...d(17, 500, dd.today ? '#fff' : NV.ink) }}>
                {dd.n}
              </span>
            </div>
          ))}
        </div>
        <div className="flex min-w-0 flex-1 overflow-hidden">
          {COLS.map((c, ci) => (
            <div key={c.s} className="w-[112px] shrink-0 grow">
              <div className="flex h-[78px] flex-col items-center justify-center px-2" style={{ background: NV.canvas, borderLeft: `0.5px solid ${NV.line}` }}>
                <span style={{ ...b(14, 800), ...tnum }}>{c.s}</span>
                <span style={{ ...b(10.5, 600, NV.muted), ...tnum }}>to {c.e}</span>
                <span className="mt-[3px] rounded-full px-1.5 py-px" style={{ background: NV.sand, ...b(9.5, 800, NV.muted) }}>
                  {c.m}m
                </span>
              </div>
              {DAYS.map((dd, di) => {
                const n = GRID[di][ci] + (di === 4 && ci === 4 ? added : 0)
                return (
                  <div key={dd.k} className="h-[96px] p-1.5" style={{ borderTop: `1px solid ${NV.line}`, background: dd.today ? 'rgba(239,240,250,.5)' : undefined }}>
                    <Cell n={n} max={max} live={dd.today && ci === 0} done={dd.k === 'MON'} roll={dd.today && ci === 0 ? '6/8' : undefined} away={dd.today && ci === 4 ? 1 : 0} people={PEOPLE.slice(0, n)} fresh={di === 4 && ci === 4 && added > 0} />
                  </div>
                )
              })}
            </div>
          ))}
        </div>
      </div>
      <span className="absolute bottom-6 right-6 z-30 flex h-14 items-center gap-2 rounded-2xl px-5 @[700px]:bottom-8 @[700px]:right-8" style={{ background: NV.brand700, boxShadow: '0 6px 16px rgba(1,0,57,.3)', ...b(14, 600, '#fff') }}>
        <Icon path={mdiPlus} size={22} color="#fff" />
        Create slot
      </span>
    </NuvaraScreen>
  )
}

function MiniStat({ v, l, icon }: { v: string; l: string; icon: string }) {
  return (
    <div className="flex items-center gap-2 rounded-2xl bg-white px-3 py-2.5" style={{ border: `1px solid ${NV.line}` }}>
      <Icon path={icon} size={18} color={NV.brand600} />
      <div>
        <span className="block" style={{ ...d(19), ...tnum }}>
          {v}
        </span>
        <span className="block" style={b(11, 600, NV.muted)}>
          {l}
        </span>
      </div>
    </div>
  )
}

/** One slot: busier slots are deeper navy so the week's shape reads at a glance. */
function Cell({ n, max, live, done, roll, away, people, fresh }: { n: number; max: number; live?: boolean; done?: boolean; roll?: string; away?: number; people: string[]; fresh?: boolean }) {
  if (n === 0)
    return (
      <div className="flex h-full items-center justify-center rounded-[14px]" style={{ border: '1px solid rgba(229,231,241,.7)' }}>
        <Icon path={mdiPlus} size={18} color="rgba(98,102,127,.45)" />
      </div>
    )
  const t = 0.25 + 0.75 * (n / max)
  const mix = (a: number, c: number) => Math.round(a + (c - a) * t * 0.85)
  const bg = `rgb(${mix(0xef, 0x16)},${mix(0xf0, 0x1a)},${mix(0xfa, 0x66)})`
  const dark = t > 0.55
  const fg = dark ? '#fff' : NV.brand900
  return (
    <div className={`flex h-full flex-col rounded-[14px] px-[9px] py-[7px] ${fresh ? 'xfade-in' : ''}`} style={{ background: bg, border: live ? `2px solid ${NV.clay500}` : '1px solid transparent' }}>
      <div className="flex items-start">
        <span className="flex-1" style={{ ...d(24, 500, fg, 1), ...tnum }}>
          {n}
        </span>
        {away ? (
          <span className="rounded-full px-[5px] py-0.5" style={{ background: NV.amber, ...b(10, 800, '#fff', 1.1) }}>
            {away} away
          </span>
        ) : null}
      </div>
      <span style={b(10, 700, dark ? 'rgba(255,255,255,.8)' : 'rgba(1,0,57,.8)')}>{n === 1 ? 'session' : 'sessions'}</span>
      <span className="flex-1" />
      <div className="flex items-center justify-between">
        <AvatarStack names={people} size={22} max={3} />
        {done ? <Icon path={mdiCheckCircle} size={15} color={dark ? '#fff' : NV.green} /> : roll ? <span style={{ ...b(10, 800, fg), ...tnum }}>{roll}</span> : null}
      </div>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  A child's profile                                                    */
/* ------------------------------------------------------------------ */
export function AdminChildScreen() {
  const c = KIDS.aarav
  const base = avatarColor(c.name)
  return (
    <NuvaraScreen role="admin" bar={<AppBar title={c.code} trailing={<Icon path={mdiDotsVertical} size={22} color={NV.ink} className="mr-2" />} />}>
      <div className="rounded-[26px] p-5" style={{ background: `linear-gradient(135deg, ${base}, #4a2c70)`, boxShadow: `0 12px 24px -8px ${base}4d` }}>
        <div className="flex items-center gap-4">
          <span className="flex h-[62px] w-[62px] shrink-0 items-center justify-center rounded-full" style={{ background: 'rgba(255,255,255,.16)', border: '1.5px solid rgba(255,255,255,.3)', ...d(23, 500, '#fff') }}>
            {initials(c.name)}
          </span>
          <div className="min-w-0 flex-1">
            <span className="block" style={d(23, 500, '#fff')}>
              {c.name}
            </span>
            <span className="mt-1.5 flex items-center gap-2">
              <IdBadge code={c.code} light />
              <span style={b(12, 400, 'rgba(255,255,255,.75)')}>Born 14 March 2020</span>
            </span>
          </div>
        </div>
        <div className="mt-4 flex gap-2">
          <Btn kind="white" icon={mdiClipboardTextOutline} h={42} className="flex-1">
            New assessment
          </Btn>
          <Btn kind="ghostDark" icon={mdiChatOutline} h={42} className="flex-1">
            Message family
          </Btn>
        </div>
      </div>
      <div className="h-[22px]" />
      <SectionTitle title="Therapies & fees" hint="Charged per attended session" />
      <Card pad={0}>
        {[
          { t: THERAPIES.speech, fee: '₹600', own: false, who: STAFF.rahul.name },
          { t: THERAPIES.ot, fee: '₹650', own: true, who: STAFF.priya.name },
        ].map((r, i) => (
          <div key={r.t.name}>
            {i > 0 && <Divider indent={16} />}
            <div className="flex items-center gap-3 px-4 py-3">
              <span className="h-8 w-1 rounded-full" style={{ background: r.t.color }} />
              <div className="min-w-0 flex-1">
                <span className="block" style={b(14.5, 700)}>
                  {r.t.name}
                </span>
                <span className="block" style={b(12, 400, NV.muted)}>
                  With {r.who}
                </span>
              </div>
              <div className="text-right">
                <span className="block" style={{ ...b(14, 700), ...tnum }}>
                  {r.fee} / session
                </span>
                {r.own && (
                  <span className="block" style={b(11, 600, NV.green)}>
                    Own fee · standard ₹700
                  </span>
                )}
              </div>
            </div>
          </div>
        ))}
      </Card>
      <div className="h-[22px]" />
      <AssessmentProgressCard />
    </NuvaraScreen>
  )
}

/* ------------------------------------------------------------------ */
/*  Fees: what each family still owes, week by week                     */
/* ------------------------------------------------------------------ */
const OWING = [
  { k: KIDS.kavin, due: '₹4,800', weeks: [['Week of 28 Sep · ₹2,400', 'red'], ['This week · ₹2,400', 'amber']] },
  { k: KIDS.aarav, due: '₹3,300', weeks: [['Week of 28 Sep · ₹3,300', 'red']] },
  { k: KIDS.diya, due: '₹1,600', weeks: [['This week · ₹1,600', 'amber']] },
  { k: KIDS.riya, due: '₹1,200', weeks: [['This week · ₹1,200', 'amber']] },
  { k: KIDS.ishaan, due: null, weeks: [] },
] as const

export function AdminFeesScreen({ paid }: { paid?: boolean }) {
  const rows = OWING.filter((o) => !(paid && o.k === KIDS.aarav))
  return (
    <NuvaraScreen role="admin" tab="fees">
      <TabHeader title="Fees" sub="Weekly, for attended sessions · pay any time" trailing={<Icon path={mdiQrcode} size={24} color={NV.ink} className="mb-1" />} />
      {paid && (
        <div className="mb-3.5 flex items-center gap-2.5 rounded-2xl py-2.5 pl-3.5 pr-2" style={{ background: NV.blueBg }}>
          <Icon path={mdiClipboardCheckOutline} size={18} color={NV.blue} />
          <span className="flex-1" style={b(13, 600, NV.blue, 1.4)}>
            1 UPI payment to tick off against the bank
          </span>
          <span className="px-2" style={b(14, 600, NV.blue)}>
            Review
          </span>
        </div>
      )}
      <Segmented
        expand
        value={0}
        options={[
          { label: 'Outstanding', icon: mdiClockOutline },
          { label: 'By week', icon: mdiCalendarBlankOutline },
        ]}
      />
      <div className="h-3.5" />
      <Hero pad={18} radius={24}>
        <span className="block" style={b(12.5, 600, NV.brand200)}>
          Outstanding now
        </span>
        <span className="block" style={{ ...d(30, 500, '#fff'), ...tnum }}>
          {paid ? '₹7,600' : '₹10,900'}
        </span>
        <div className="mt-2.5 flex flex-wrap gap-x-3.5 gap-y-1">
          <span style={b(12, 700, '#fff')}>{paid ? 3 : 4} children to collect from</span>
          <span style={b(12, 600, '#FCA5A5')}>{paid ? 1 : 2} with earlier weeks unpaid</span>
          <span style={b(12, 600, NV.brand100)}>{paid ? 21 : 20} fully paid</span>
        </div>
      </Hero>
      <div className="h-4" />
      <div className="flex h-12 items-center gap-3 rounded-[14px] bg-white px-3.5" style={{ border: '1px solid #8F94AD' }}>
        <Icon path={mdiMagnify} size={21} color={NV.muted} />
        <span style={b(15, 400, NV.muted)}>Search child by name or ID</span>
      </div>
      <div className="mt-3 flex gap-2">
        <FilterChip label="To collect" n={paid ? 3 : 4} dot={NV.red} active />
        <FilterChip label="Fully paid" n={paid ? 21 : 20} dot={NV.green} />
        <FilterChip label="Everyone" n={24} />
      </div>
      <div className="mt-3 overflow-hidden rounded-[20px] bg-white" style={{ border: `1px solid ${NV.line}` }}>
        {rows.map((o, i) => (
          <div key={o.k.code}>
            {i > 0 && <Divider indent={70} />}
            <div className="flex items-start gap-3.5 py-3 pl-3.5 pr-3">
              <Avatar name={o.k.name} size={42} />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="flex min-w-0 flex-1 items-center gap-[7px]">
                    <span className="truncate" style={b(14.5, 600)}>
                      {o.k.name}
                    </span>
                    <IdBadge code={o.k.code} />
                  </span>
                  {o.due ? (
                    <span style={{ ...b(14.5, 800, NV.clay600), ...tnum }}>{o.due} due</span>
                  ) : (
                    <Chip tone="green">Fully paid</Chip>
                  )}
                </div>
                {o.weeks.length > 0 && (
                  <div className="mt-1.5 flex flex-wrap gap-1.5">
                    {o.weeks.map(([l, tone]) => (
                      <Chip key={l} tone={tone} dot={false}>
                        {l}
                      </Chip>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </NuvaraScreen>
  )
}

function FilterChip({ label, n, dot, active }: { label: string; n: number; dot?: string; active?: boolean }) {
  return (
    <span className="flex items-center gap-1.5 rounded-full py-2 pl-3 pr-2" style={{ background: active ? NV.brand800 : '#fff', border: `1px solid ${active ? NV.brand800 : NV.line}` }}>
      {dot && <span className="h-[7px] w-[7px] rounded-full" style={{ background: dot }} />}
      <span style={b(13, 700, active ? '#fff' : NV.ink)}>{label}</span>
      <span className="rounded-full px-[7px] py-0.5" style={{ background: active ? 'rgba(255,255,255,.18)' : NV.sand, ...b(11, 800, active ? '#fff' : NV.muted) }}>
        {n}
      </span>
    </span>
  )
}

/* ------------------------------------------------------------------ */
/*  Slot requests                                                        */
/* ------------------------------------------------------------------ */
export function AdminRequestsScreen() {
  return (
    <NuvaraScreen role="admin" bar={<AppBar title="Slot requests" />}>
      <SectionTitle title="Waiting for you" hint="1 request" />
      <Card border={`${NV.violet}59`}>
        <div className="flex items-center gap-2.5">
          <Avatar name={KIDS.aarav.name} size={34} />
          <div className="min-w-0 flex-1">
            <span className="block truncate" style={b(14.5, 700)}>
              {KIDS.aarav.name} · {KIDS.aarav.code}
            </span>
            <span className="block" style={b(12, 400, NV.muted)}>
              For this day only
            </span>
          </div>
          <Chip tone="violet">Needs your answer</Chip>
        </div>
        <div className="mt-3 rounded-2xl p-3" style={{ background: NV.canvas, border: `1px solid ${NV.line}` }}>
          <MoveRow label="Booked" main="Fri, 9 Oct · 11:15 AM – 12:00 PM" hint={`OT · Room 2 · ${STAFF.priya.name}`} />
          <div className="my-1.5 flex items-center gap-2 pl-2">
            <Icon path={mdiArrowRight} size={16} color={NV.violet} className="rotate-90" />
          </div>
          <MoveRow label="Family asks for" main="Fri, 9 Oct · 3:30 – 4:15 PM" hint="Suggested time: a session needs arranging" accent />
        </div>
        <span className="mt-2.5 block italic" style={b(13, 400, NV.ink, 1.4)}>
          &ldquo;His school has a sports day on Friday morning.&rdquo;
        </span>
        <span className="mt-1.5 block" style={b(11.5, 400, NV.muted)}>
          Asked 12m ago
        </span>
        <div className="mt-2.5 flex gap-2">
          <Btn kind="outlined" h={44} className="flex-1" style={{ color: NV.red, borderColor: '#F3C4CB' }}>
            Turn down
          </Btn>
          <Btn icon={mdiCalendarSync} h={44} className="flex-[1.6]">
            Arrange a slot
          </Btn>
        </div>
      </Card>
      <div className="h-6" />
      <SectionTitle title="Answered" />
      <Card>
        <div className="flex items-center gap-2.5">
          <Avatar name={KIDS.riya.name} size={34} />
          <div className="min-w-0 flex-1">
            <span className="block truncate" style={b(14.5, 700)}>
              {KIDS.riya.name} · {KIDS.riya.code}
            </span>
            <span className="block" style={b(12, 400, NV.muted)}>
              Regularly, from this session on
            </span>
          </div>
          <Chip tone="green">Approved</Chip>
        </div>
        <div className="mt-3 rounded-2xl p-3" style={{ background: NV.greenBg }}>
          <MoveRow label="Moved to" main="Every Wednesday · 2:00 – 2:45 PM" hint="4 sessions moved" />
        </div>
      </Card>
    </NuvaraScreen>
  )
}

function MoveRow({ label, main, hint, accent }: { label: string; main: string; hint: string; accent?: boolean }) {
  return (
    <div>
      <span className="block uppercase" style={{ ...b(10.5, 800, accent ? NV.violet : NV.muted), letterSpacing: 0.8 }}>
        {label}
      </span>
      <span className="block" style={{ ...b(14, 700), ...tnum }}>
        {main}
      </span>
      <span className="block" style={b(12, 400, NV.muted)}>
        {hint}
      </span>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Messages                                                             */
/* ------------------------------------------------------------------ */
export function AdminMessagesScreen() {
  return (
    <NuvaraScreen role="admin" tab="messages">
      <TabHeader title="Messages" sub="2 unread messages" />
      <Hub color="#C2622D" icon={mdiAccountGroupOutline} title="Parents" line="Diya: Thank you, we will be there by 10." meta="18 conversations · 1 unread · 9:32 AM" unread={1} />
      <div className="h-3" />
      <Hub color="#3D64A8" icon={mdiCardAccountDetails} title="Therapists" line="Kumar: Room 3 projector is fixed now." meta="4 conversations · 1 unread · 8:55 AM" unread={1} />
      <div className="mt-4 flex items-start gap-2">
        <Icon path={mdiLockOutline} size={16} color={NV.muted} className="mt-0.5 shrink-0" />
        <span style={b(12.5, 400, NV.muted, 1.4)}>Families and therapists each talk only with the centre. They can&rsquo;t message one another.</span>
      </div>
      <div className="h-6" />
      <SectionTitle title="Recent" />
      <div className="overflow-hidden rounded-[20px] bg-white" style={{ border: `1px solid ${NV.line}` }}>
        <Thread name={KIDS.diya.name} code={KIDS.diya.code} line="Thank you, we will be there by 10." when="9:32 AM" unread />
        <Divider indent={76} />
        <Thread name={KIDS.aarav.name} code={KIDS.aarav.code} line="You: Of course. Tap “Change” on Friday’s session…" when="9:20 AM" mine />
        <Divider indent={76} />
        <Thread name={KIDS.meher.name} code={KIDS.meher.code} line="She has a fever since last night, sorry." when="8:41 AM" />
      </div>
    </NuvaraScreen>
  )
}

function Hub({ color, icon, title, line, meta, unread }: { color: string; icon: string; title: string; line: string; meta: string; unread: number }) {
  return (
    <Card>
      <div className="flex items-center gap-3.5">
        <span className="relative">
          <IconTile path={icon} color={color} size={52} />
          {unread > 0 && (
            <span className="absolute -right-1.5 -top-1.5 flex h-4 min-w-4 items-center justify-center rounded-full px-1" style={{ background: NV.clay600, ...b(10.5, 700, '#fff') }}>
              {unread}
            </span>
          )}
        </span>
        <div className="min-w-0 flex-1">
          <span className="block" style={d(21)}>
            {title}
          </span>
          <span className="mt-0.5 block truncate" style={b(13, 700)}>
            {line}
          </span>
          <span className="mt-0.5 block" style={b(12, 600, NV.brand700)}>
            {meta}
          </span>
        </div>
        <Icon path={mdiChevronRight} size={22} color={NV.muted} />
      </div>
    </Card>
  )
}

function Thread({ name, code, line, when, unread, mine }: { name: string; code: string; line: string; when: string; unread?: boolean; mine?: boolean }) {
  return (
    <div className="flex items-center gap-3.5 px-3.5 py-3">
      <Avatar name={name} size={48} />
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="flex min-w-0 flex-1 items-center gap-[7px]">
            <span className="truncate" style={b(15, unread ? 800 : 600)}>
              {name}
            </span>
            <IdBadge code={code} />
          </span>
          <span style={b(11.5, unread ? 800 : 500, unread ? NV.brand700 : NV.muted)}>{when}</span>
        </div>
        <div className="mt-[3px] flex items-center gap-1">
          {mine && <Icon path={mdiCheck} size={15} color={NV.blue} />}
          <span className="flex-1 truncate" style={b(13, unread ? 700 : 400, unread ? NV.ink : NV.muted)}>
            {line}
          </span>
          {unread && (
            <span className="min-w-[22px] rounded-full px-[7px] py-[3px] text-center" style={{ background: NV.brand700, ...b(11, 800, '#fff', 1.2) }}>
              1
            </span>
          )}
        </div>
      </div>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Pediatric OT assessment (lib/assessment)                            */
/* ------------------------------------------------------------------ */
export const SECTIONS = [
  'Demographics',
  'Medical History',
  'Special Senses',
  'Development',
  'Education',
  'Play',
  'Screen Time',
  'Behaviour',
  'Sensory',
  'Posture',
  'Reflexes',
  'ROM & Strength',
  'Hand Function',
  'ADL',
  'Treatment Plan',
  'Goals',
  'Approaches',
  'Home Program',
]

const BEHAVIOURS = ['Self Injury', 'Harming Others and Surroundings', 'Inattentive', 'Hyperactive', 'Nail Biting', 'Drowsy']
/** The answer each behaviour gets as the assessment fills in. */
const ANSWERS: (0 | 1 | 2)[] = [1, 1, 0, 1, 1, 1]

type AssessProps = {
  /** How many behaviour items are answered so far (0–6). */
  answered?: number
}

export function AssessmentScreen({ answered = 4 }: AssessProps) {
  const current = 7
  const recorded = Math.min(answered, BEHAVIOURS.length)
  const done = current + (recorded === BEHAVIOURS.length ? 1 : 0)
  const pct = Math.round(((current + recorded / BEHAVIOURS.length) / SECTIONS.length) * 100)
  return (
    <div className="nv absolute inset-0 overflow-hidden" style={{ background: NV.canvas }}>
      <div className="absolute inset-x-0 top-0 h-[50px] bg-white @[700px]:h-[30px]" />
      <StatusBar />
      {/* Header */}
      <div className="absolute inset-x-0 top-[50px] z-10 bg-white pb-2.5 pt-1.5 @[700px]:top-[30px]" style={{ borderBottom: `1px solid ${NV.line}` }}>
        <div className="flex items-center gap-1 pl-1 pr-2 @[700px]:gap-3 @[700px]:pl-3 @[700px]:pr-4">
          <span className="flex h-10 w-10 items-center justify-center">
            <Icon path={mdiArrowLeft} size={22} color={NV.ink} />
          </span>
          <span className="hidden @[700px]:block">
            <NuvaraMark size={30} />
          </span>
          <div className="min-w-0 flex-1">
            <span className="block truncate uppercase" style={{ ...b(10.5, 800, NV.clay600), letterSpacing: 1 }}>
              Pediatric OT assessment
            </span>
            <span className="mt-0.5 flex items-center gap-2">
              <span className="truncate" style={d(17)}>
                {KIDS.aarav.name}
              </span>
              <IdBadge code={KIDS.aarav.code} />
            </span>
          </div>
          <span className="hidden items-center gap-1 @[700px]:flex" style={b(12, 700, NV.green)}>
            <Icon path={mdiCloudCheckOutline} size={16} color={NV.green} />
            Saved
          </span>
          <span className="hidden h-10 items-center gap-2 rounded-[14px] bg-white px-3.5 @[700px]:flex" style={{ border: `1px solid ${NV.line}`, ...b(14, 600) }}>
            <Icon path={mdiContentSaveOutline} size={18} color={NV.ink} />
            Save draft &amp; exit
          </span>
          <Icon path={mdiDotsVertical} size={22} color={NV.ink} />
        </div>
        <div className="mt-2 flex flex-wrap gap-2 px-3 @[700px]:px-5">
          <MetaChip icon={mdiShapeOutline}>Re-assessment</MetaChip>
          <MetaChip icon={mdiCalendarBlankOutline}>6 Oct 2026</MetaChip>
          <MetaChip icon={mdiAccountOutline}>{STAFF.priya.name}</MetaChip>
        </div>
        <div className="mt-2.5 flex items-center gap-2.5 px-3 @[700px]:px-5">
          <span style={b(12, 600, NV.muted)}>Assessment progress</span>
          <span className="flex-1">
            <Bar value={pct / 100} h={6} />
          </span>
          <span style={{ ...b(13, 800), ...tnum }}>{pct}%</span>
        </div>
      </div>
      {/* Body */}
      <div className="absolute inset-x-0 bottom-0 top-[214px] flex @[700px]:top-[170px]">
        <div className="hidden w-[270px] shrink-0 overflow-hidden bg-white px-3 pt-3.5 @[700px]:block" style={{ borderRight: `1px solid ${NV.line}` }}>
          <div className="flex items-center px-2 pb-2.5">
            <span className="flex-1 uppercase" style={{ ...b(11, 800, NV.muted), letterSpacing: 1.1 }}>
              Sections
            </span>
            <span style={b(11.5, 700, NV.muted)}>
              {done} of {SECTIONS.length} done
            </span>
          </div>
          {SECTIONS.map((s, i) => (
            <div key={s} className="mb-0.5 flex items-center gap-3 rounded-xl px-2.5 py-[5px]" style={{ background: i === current ? NV.brand50 : 'transparent' }}>
              <SectionMark n={i + 1} done={i < done} part={i === current ? recorded / BEHAVIOURS.length : 0} current={i === current} />
              <span className="flex-1 truncate" style={b(13.5, i === current ? 800 : 600, i === current ? NV.brand900 : NV.ink)}>
                {s}
              </span>
              {i === current && recorded < 6 && <span style={{ ...b(11, 700, NV.muted), ...tnum }}>{recorded}/6</span>}
            </div>
          ))}
        </div>
        <div className="min-w-0 flex-1 overflow-hidden px-3.5 pt-5 @[700px]:px-6">
          {/* Phones: the sections as a strip */}
          <div className="-mt-2 mb-4 flex gap-1.5 overflow-hidden @[700px]:hidden">
            {SECTIONS.slice(5, 11).map((s, i) => {
              const idx = i + 5
              const cur = idx === current
              return (
                <span key={s} className="flex shrink-0 items-center gap-1.5 rounded-full py-1.5 pl-1.5 pr-3" style={{ background: cur ? NV.brand800 : '#fff', border: `1px solid ${cur ? NV.brand800 : NV.line}` }}>
                  <span className="flex h-5 w-5 items-center justify-center rounded-full" style={{ background: idx < done ? NV.green : cur ? 'rgba(255,255,255,.15)' : NV.sand }}>
                    {idx < done ? <Icon path={mdiCheck} size={13} color="#fff" /> : <span style={b(10, 800, cur ? NV.brand200 : NV.muted)}>{idx + 1}</span>}
                  </span>
                  <span style={b(12.5, 700, cur ? '#fff' : NV.ink)}>{s}</span>
                </span>
              )
            })}
          </div>
          <div className="mx-auto max-w-[880px]">
            <span className="block uppercase" style={{ ...b(11, 800, NV.muted), letterSpacing: 1 }}>
              Section {current + 1} of {SECTIONS.length}
            </span>
            <div className="mt-1 flex flex-wrap items-end justify-between gap-2">
              <div>
                <span className="block" style={d(24, 500)}>
                  Behavioural Assessment
                </span>
                <span className="mt-1 flex items-center gap-1.5" style={b(12.5, 600, recorded === 6 ? NV.green : NV.muted)}>
                  <Icon path={recorded === 6 ? mdiCheckCircle : mdiClockOutline} size={15} color={recorded === 6 ? NV.green : NV.muted} />
                  {recorded === 6 ? 'All recorded' : `${recorded} of 6 recorded`}
                </span>
              </div>
              {recorded < 6 && (
                <span className="flex h-10 items-center gap-1.5 rounded-xl px-3" style={{ background: NV.brand50, ...b(13, 700, NV.brand800) }}>
                  <Icon path={mdiCheck} size={16} color={NV.brand800} />
                  Mark the rest
                </span>
              )}
            </div>
            <div className="mt-4 overflow-hidden rounded-[20px] bg-white" style={{ border: `1px solid ${NV.line}`, boxShadow: softShadow }}>
              {BEHAVIOURS.map((label, i) => (
                <div key={label}>
                  {i > 0 && <Divider />}
                  <ItemRow label={label} value={i < recorded ? ANSWERS[i] : null} severity={i === 2 && i < recorded} />
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function MetaChip({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <span className="flex h-9 items-center gap-1.5 rounded-full bg-white px-3" style={{ border: `1px solid ${NV.line}` }}>
      <Icon path={icon} size={16} color={NV.brand700} />
      <span style={b(12.5, 700)}>{children}</span>
    </span>
  )
}

function SectionMark({ n, done, part, current }: { n: number; done: boolean; part: number; current: boolean }) {
  if (done)
    return (
      <span className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-full" style={{ background: NV.green }}>
        <Icon path={mdiCheck} size={16} color="#fff" />
      </span>
    )
  const r = 11.7
  const c = 2 * Math.PI * r
  return (
    <span className="relative flex h-[26px] w-[26px] shrink-0 items-center justify-center">
      <svg viewBox="0 0 26 26" className="absolute inset-0 -rotate-90">
        <circle cx="13" cy="13" r={r} fill="none" stroke={current ? NV.brand100 : NV.line} strokeWidth="2.6" />
        <circle cx="13" cy="13" r={r} fill="none" stroke={NV.clay500} strokeWidth="2.6" strokeDasharray={`${c * part} ${c}`} style={{ transition: 'stroke-dasharray .4s' }} />
      </svg>
      <span style={{ ...b(10.5, 800, current ? NV.brand800 : NV.muted), ...tnum }}>{n}</span>
    </span>
  )
}

const PILLS = [
  { l: 'Present', fg: NV.amber, bg: NV.amberBg },
  { l: 'Absent', fg: NV.green, bg: NV.greenBg },
  { l: 'Not assessed', fg: NV.brand700, bg: NV.brand50 },
]

/** One item: its name, one-tap answer pills, and the follow-up that opens when the answer needs one. */
function ItemRow({ label, value, severity }: { label: string; value: 0 | 1 | 2 | null; severity?: boolean }) {
  return (
    <div className="px-4 pb-3.5 pt-3 @[640px]:flex @[640px]:items-start">
      <div className="flex items-center @[640px]:w-[190px] @[640px]:shrink-0 @[640px]:pr-3 @[640px]:pt-[11px]">
        <span className="flex-1" style={b(14.5, 700, NV.ink, 1.25)}>
          {label}
        </span>
        <span className="@[640px]:hidden">
          <Icon path={mdiNoteTextOutline} size={20} color={NV.muted} />
        </span>
      </div>
      <div className="mt-1.5 flex-1 @[640px]:mt-0">
        <div className="flex flex-wrap gap-2">
          {PILLS.map((p, i) => {
            const on = value === i
            return (
              <span
                key={p.l}
                className="flex h-[42px] items-center gap-[5px] rounded-[11px] px-[13px] transition-colors duration-300"
                style={{ background: on ? p.bg : '#fff', border: `${on ? 1.4 : 1}px solid ${on ? `${p.fg}8c` : NV.line}` }}
              >
                {on && <Icon path={mdiCheck} size={16} color={p.fg} />}
                <span style={b(13.5, on ? 700 : 600, on ? p.fg : NV.ink, 1.2)}>{p.l}</span>
              </span>
            )
          })}
        </div>
        {severity && (
          <div className="xfade-in mt-3 rounded-[14px] p-3" style={{ background: NV.canvas, border: `1px solid ${NV.line}` }}>
            <span className="block pb-2" style={b(12.5, 700)}>
              Severity
            </span>
            <div className="flex flex-wrap gap-2">
              {['Mild', 'Moderate', 'Severe'].map((s, i) => (
                <span key={s} className="flex h-9 items-center gap-1 rounded-[11px] px-2.5" style={{ background: i === 0 ? NV.blueBg : '#fff', border: `${i === 0 ? 1.4 : 1}px solid ${i === 0 ? `${NV.blue}8c` : NV.line}` }}>
                  {i === 0 && <Icon path={mdiCheck} size={14} color={NV.blue} />}
                  <span style={b(12.5, i === 0 ? 700 : 600, i === 0 ? NV.blue : NV.ink)}>{s}</span>
                </span>
              ))}
            </div>
          </div>
        )}
      </div>
      <span className="hidden w-10 justify-end pt-[11px] @[640px]:flex">
        <Icon path={mdiNoteTextOutline} size={20} color={NV.muted} />
      </span>
    </div>
  )
}
