import {
  mdiBookOpenVariant,
  mdiBus,
  mdiCalendarCheckOutline,
  mdiChevronLeft,
  mdiChevronRight,
  mdiAccountOutline,
  mdiPhoneOutline,
  mdiReceiptTextOutline,
  mdiSchoolOutline,
  mdiStar,
  mdiMapMarker,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { STUDENT } from '../../data/sample'
import { AppBar, Badge, Card, ConnectScreen, IconTile, PC, SectionHeader } from './kit'

/* ---------------------------------------------------------------- */
/*  Progress tab — progress_screen                                    */
/* ---------------------------------------------------------------- */
const LEVELS = ['Emerging', 'Developing', 'Proficient', 'Advanced']
export const SKILLS = [
  { s: 'Reading', l: 2 },
  { s: 'Teamwork', l: 3 },
  { s: 'Problem solving', l: 1 },
  { s: 'Public speaking', l: 0 },
]

export function ProgressScreen({ grow = 1 }: { grow?: number }) {
  return (
    <ConnectScreen nav="progress">
      <div className="px-4 pt-1">
        <span className="pc-display text-[24px] font-semibold" style={{ color: PC.charcoal }}>
          Progress
        </span>
        <div className="mt-3 grid grid-cols-3 gap-2">
          {[
            { p: mdiCalendarCheckOutline, c: PC.leafGreen, l: 'Attendance', v: '95%' },
            { p: mdiBookOpenVariant, c: PC.primaryBlue, l: 'Homework', v: '92%' },
            { p: mdiSchoolOutline, c: '#7C3AED', l: 'Latest exam', v: '88.8%' },
          ].map((k) => (
            <Card key={k.l} className="!p-3">
              <IconTile path={k.p} color={k.c} size={34} iconSize={19} />
              <span className="mt-2 block text-[20px] font-bold tracking-[-0.4px]" style={{ color: PC.charcoal }}>
                {k.v}
              </span>
              <span className="text-[11.5px]" style={{ color: PC.grey500 }}>
                {k.l}
              </span>
            </Card>
          ))}
        </div>

        <Card luminous className="mt-3 flex items-center gap-3" style={{ background: 'linear-gradient(135deg,#FFF8E6,#FFFFFF)' }}>
          <span className="flex h-12 w-12 items-center justify-center rounded-full" style={{ background: '#F5A52426' }}>
            <Icon path={mdiStar} size={28} color={PC.star} />
          </span>
          <div className="flex-1">
            <span className="block text-[22px] font-bold leading-none" style={{ color: PC.charcoal }}>
              24 <span className="text-[13px] font-semibold" style={{ color: PC.grey500 }}>Stars earned</span>
            </span>
            <span className="text-[12.5px]" style={{ color: PC.grey500 }}>
              Latest from {STUDENT.teacher} · kindness
            </span>
          </div>
          <Badge tone="success">+3 this week</Badge>
        </Card>

        <div className="mt-5">
          <SectionHeader title="Skills" action="See all" />
          <Card className="flex flex-col gap-3.5">
            {SKILLS.map((k) => {
              const level = Math.min(k.l, Math.floor(grow * 4 - 0.001))
              return (
                <div key={k.s}>
                  <div className="flex justify-between text-[13.5px]">
                    <span className="font-semibold" style={{ color: PC.charcoal }}>
                      {k.s}
                    </span>
                    <span className="font-semibold" style={{ color: PC.primaryBlue }}>
                      {LEVELS[Math.max(0, level)]}
                    </span>
                  </div>
                  <div className="mt-1.5 grid grid-cols-4 gap-1">
                    {LEVELS.map((_, li) => (
                      <span key={li} className="h-1.5 rounded-full transition-colors duration-700" style={{ background: li <= level ? 'linear-gradient(90deg,#2F6BFF,#3EC6FF)' : PC.grey200 }} />
                    ))}
                  </div>
                </div>
              )
            })}
            <span className="text-[11.5px]" style={{ color: PC.grey400 }}>
              Emerging → Developing → Proficient → Advanced
            </span>
          </Card>
        </div>

        <div className="mt-5">
          <SectionHeader title="Teacher notes" action="See all" />
          <Card>
            <p className="text-[14px] leading-snug" style={{ color: PC.charcoal }}>
              “Aadhya explains her thinking clearly in maths. Encourage her to read aloud at home.”
            </p>
            <span className="mt-2 block text-[12px]" style={{ color: PC.grey500 }}>
              By {STUDENT.teacher}
            </span>
          </Card>
        </div>
      </div>
    </ConnectScreen>
  )
}

/* ---------------------------------------------------------------- */
/*  Attendance — attendance_screen calendar                           */
/* ---------------------------------------------------------------- */
// September 2026 starts on a Tuesday. P present, A absent, L leave,
// - weekend, F after today (the 25th).
export const SEPT = 'PPPP--PPPPP--PPPPL--PPPPP--FFF'.split('')

export function AttendanceScreen({ reveal = 1 }: { reveal?: number }) {
  const shown = Math.round(SEPT.length * reveal)
  const color = (c: string) => (c === 'P' ? PC.success : c === 'A' ? PC.error : c === 'L' ? PC.warning : 'transparent')
  const blank = (c: string) => c === '-' || c === 'F'
  const counted = SEPT.slice(0, shown)
  const P = counted.filter((c) => c === 'P').length
  const A = counted.filter((c) => c === 'A').length
  const Lv = counted.filter((c) => c === 'L').length
  const pct = P + A + Lv ? Math.round((P / (P + A + Lv)) * 100) : 0
  return (
    <ConnectScreen>
      <AppBar title="Attendance" />
      <div className="px-4">
        <Card luminous className="flex items-center gap-4">
          <Ring pct={pct} />
          <div className="flex-1 space-y-1.5 text-[13px]">
            {[
              ['Present', P, PC.success],
              ['Absent', A, PC.error],
              ['Leave', Lv, PC.warning],
            ].map(([k, v, c]) => (
              <div key={k as string} className="flex items-center gap-2">
                <span className="h-2.5 w-2.5 rounded-full" style={{ background: c as string }} />
                <span className="flex-1" style={{ color: PC.grey600 }}>
                  {k}
                </span>
                <span className="font-bold" style={{ color: PC.charcoal }}>
                  {v}
                </span>
              </div>
            ))}
          </div>
        </Card>

        <Card className="mt-3">
          <div className="flex items-center">
            <span className="flex-1 text-[17px] font-semibold" style={{ color: PC.charcoal }}>
              Calendar
            </span>
            <Icon path={mdiChevronLeft} size={22} color={PC.grey600} />
            <span className="px-2 text-[13px] font-semibold" style={{ color: PC.charcoal }}>
              Sep 2026
            </span>
            <Icon path={mdiChevronRight} size={22} color={PC.grey600} />
          </div>
          <div className="mt-3 grid grid-cols-7 gap-y-2 text-center">
            {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) => (
              <span key={i} className="text-[11.5px] font-semibold" style={{ color: PC.grey500 }}>
                {d}
              </span>
            ))}
            <span />
            {SEPT.map((c, i) => {
              const on = i < shown && !blank(c)
              return (
                <span key={i} className="flex flex-col items-center gap-1">
                  <span className="text-[13px]" style={{ color: blank(c) ? PC.grey400 : PC.charcoal, fontWeight: i === 24 ? 700 : 500 }}>
                    {i + 1}
                  </span>
                  <span className="h-1.5 w-1.5 rounded-full transition-all duration-500" style={{ background: on ? color(c) : 'transparent', transform: on ? 'scale(1)' : 'scale(0)' }} />
                </span>
              )
            })}
          </div>
          <div className="mt-4 flex justify-center gap-5 text-[12px]" style={{ color: PC.grey600 }}>
            <Legend c={PC.success} l="Present" />
            <Legend c={PC.error} l="Absent" />
            <Legend c={PC.warning} l="Leave" />
          </div>
        </Card>
      </div>
    </ConnectScreen>
  )
}

function Legend({ c, l }: { c: string; l: string }) {
  return (
    <span className="flex items-center gap-1.5">
      <span className="h-2 w-2 rounded-full" style={{ background: c }} />
      {l}
    </span>
  )
}

function Ring({ pct }: { pct: number }) {
  const r = 34
  const C = 2 * Math.PI * r
  return (
    <span className="relative flex h-[88px] w-[88px] items-center justify-center">
      <svg viewBox="0 0 88 88" className="absolute inset-0 -rotate-90">
        <circle cx="44" cy="44" r={r} fill="none" stroke={PC.grey200} strokeWidth="8" />
        <circle cx="44" cy="44" r={r} fill="none" stroke="url(#ringg)" strokeWidth="8" strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * (1 - pct / 100)} style={{ transition: 'stroke-dashoffset .6s' }} />
        <defs>
          <linearGradient id="ringg">
            <stop offset="0" stopColor="#22C55E" />
            <stop offset="1" stopColor="#3EC6FF" />
          </linearGradient>
        </defs>
      </svg>
      <span className="text-center">
        <span className="block text-[20px] font-bold leading-none" style={{ color: PC.charcoal }}>
          {pct}%
        </span>
        <span className="text-[10px]" style={{ color: PC.grey500 }}>
          attendance
        </span>
      </span>
    </span>
  )
}

/* ---------------------------------------------------------------- */
/*  Fees — fees_screen                                                */
/* ---------------------------------------------------------------- */
export const inr = (n: number) => '₹' + n.toLocaleString('en-IN')

export function FeesScreen({ paid = false }: { paid?: boolean }) {
  const total = 48000
  const done = paid ? 48000 : 36000
  return (
    <ConnectScreen>
      <AppBar title="Fee due" />
      <div className="px-4">
        <p className="mb-2 text-[13.5px]" style={{ color: PC.grey600 }}>
          Academic year: {STUDENT.year}
        </p>
        <Card luminous>
          {[
            ['Total', inr(total)],
            ['Paid', inr(done)],
          ].map(([k, v]) => (
            <div key={k} className="flex justify-between py-1 text-[15px]" style={{ color: PC.charcoal }}>
              <span>{k}</span>
              <span className="font-medium">{v}</span>
            </div>
          ))}
          <div className="my-2 h-px" style={{ background: PC.grey200 }} />
          <div className="flex justify-between py-1 text-[17px] font-bold" style={{ color: paid ? PC.success : PC.charcoal }}>
            <span>Remaining balance</span>
            <span>{inr(total - done)}</span>
          </div>
          <div className="mt-3 flex h-12 items-center justify-center rounded-[16px] text-[15px] font-semibold text-white transition-colors duration-500" style={{ background: paid ? PC.success : PC.primaryBlue }}>
            {paid ? 'Fees Paid' : 'Pay Now'}
          </div>
        </Card>
        <div className="mt-4 flex flex-col gap-2">
          {[
            ['Tuition fee', 36000, paid ? 36000 : 27000],
            ['Transport fee', 9000, paid ? 9000 : 6000],
            ['Activity fee', 3000, 3000],
          ].map(([k, t, p]) => (
            <Card key={k as string} className="!py-3">
              <div className="flex justify-between text-[14.5px]">
                <span className="font-semibold" style={{ color: PC.charcoal }}>
                  {k}
                </span>
                <span style={{ color: PC.grey600 }}>
                  {inr(p as number)} / {inr(t as number)}
                </span>
              </div>
              <div className="mt-2 h-1.5 overflow-hidden rounded-full" style={{ background: PC.grey200 }}>
                <div className="h-full rounded-full transition-[width] duration-700" style={{ width: `${((p as number) / (t as number)) * 100}%`, background: 'linear-gradient(90deg,#2F6BFF,#3EC6FF)' }} />
              </div>
            </Card>
          ))}
        </div>
        <div className="mt-4">
          <SectionHeader title="Payment history" />
          {paid && <Receipt date="25 Sep 2026" amount={12000} id="RCPT-1107" />}
          <Receipt date="12 Jun 2026" amount={36000} id="RCPT-1042" />
        </div>
      </div>
    </ConnectScreen>
  )
}

function Receipt({ date, amount, id }: { date: string; amount: number; id: string }) {
  return (
    <Card className="mb-2 flex items-center gap-3 !py-3">
      <IconTile path={mdiReceiptTextOutline} color={PC.success} size={38} iconSize={20} />
      <div className="flex-1">
        <span className="block text-[14px] font-semibold" style={{ color: PC.charcoal }}>
          {date}
        </span>
        <span className="text-[12px]" style={{ color: PC.grey500 }}>
          Receipt {id}
        </span>
      </div>
      <div className="text-right">
        <span className="pc-display block text-[17px] font-semibold" style={{ color: PC.charcoal }}>
          {inr(amount)}
        </span>
        <Badge tone="success">Successful</Badge>
      </div>
    </Card>
  )
}

/* ---------------------------------------------------------------- */
/*  Bus tracking — bus_tracking_screen (a stop timeline, no map SDK)  */
/* ---------------------------------------------------------------- */
export const STOPS = ['School', 'Anna Street', 'Lake View', 'Gandhi Nagar', 'Temple Road', 'Park Avenue']
export const CHILD_STOP = 5

export function BusScreen({ at = 3 }: { at?: number }) {
  const idx = Math.max(0, Math.min(STOPS.length - 1, at))
  const away = CHILD_STOP - idx
  const title = away <= 0 ? `Near ${STOPS[CHILD_STOP]}` : `Near ${STOPS[idx]}`
  const sub = away <= 0 ? 'At or close to your stop · updated just now' : away === 1 ? '1 stop before yours · updated just now' : `${away} stops before yours · updated just now`
  return (
    <ConnectScreen>
      <AppBar title="Bus Tracking" />
      <div className="px-4">
        <Card luminous className="flex items-center gap-3">
          <span className="flex h-12 w-12 items-center justify-center rounded-[14px]" style={{ background: `${PC.success}22` }}>
            <Icon path={mdiBus} size={26} color={PC.success} />
          </span>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <span className="flex items-center gap-1 rounded-full px-2 py-[2px] text-[10.5px] font-bold tracking-[0.8px]" style={{ background: `${PC.success}1f`, color: PC.success }}>
                <span className="h-1.5 w-1.5 animate-pulse rounded-full" style={{ background: PC.success }} />
                LIVE
              </span>
              <span className="text-[12px] font-semibold" style={{ color: PC.grey500 }}>
                {away <= 0 ? '8' : '32'} km/h
              </span>
            </div>
            <span className="mt-0.5 block text-[16px] font-bold" style={{ color: PC.charcoal }}>
              {title}
            </span>
            <span className="block text-[12.5px]" style={{ color: PC.grey500 }}>
              {sub}
            </span>
          </div>
        </Card>

        <Card className="mt-3">
          <span className="text-[12px] font-medium" style={{ color: PC.grey500 }}>
            Route
          </span>
          <span className="block text-[15px] font-semibold" style={{ color: PC.charcoal }}>
            Route 4 · North loop
          </span>
          <div className="mt-3">
            {STOPS.map((s, i) => {
              const passed = i < idx
              const here = i === idx
              const child = i === CHILD_STOP
              return (
                <div key={s} className="flex gap-3">
                  <div className="flex w-5 flex-col items-center">
                    <span
                      className="mt-1 h-3.5 w-3.5 rounded-full border-2 transition-colors duration-500"
                      style={{ borderColor: passed || here ? PC.success : child ? PC.primaryBlue : PC.grey200, background: passed ? PC.success : here ? '#fff' : child ? PC.primaryBlue : '#fff' }}
                    />
                    {i < STOPS.length - 1 && <span className="w-[2px] flex-1 transition-colors duration-500" style={{ background: passed ? PC.success : PC.grey200, minHeight: 26 }} />}
                  </div>
                  <div className="flex flex-1 items-start justify-between pb-3">
                    <span className="text-[14.5px]" style={{ color: passed ? PC.grey400 : PC.charcoal, fontWeight: here || child ? 700 : 500 }}>
                      {s}
                    </span>
                    <span className="flex gap-1.5">
                      {child && <Pill color={PC.primaryBlue}>Your stop</Pill>}
                      {here && (
                        <Pill color={PC.success} icon>
                          Bus is here
                        </Pill>
                      )}
                    </span>
                  </div>
                </div>
              )
            })}
          </div>
        </Card>

        <Card className="mt-3 space-y-2.5 text-[13.5px]">
          <Row icon={mdiBus} k="Vehicle" v="Bus 07" />
          <Row icon={mdiAccountOutline} k="Driver" v="Ravi K." />
          <Row icon={mdiPhoneOutline} k="Driver phone" v="+00 00000 00000" />
        </Card>
      </div>
    </ConnectScreen>
  )
}

function Pill({ children, color, icon }: { children: React.ReactNode; color: string; icon?: boolean }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-full px-2 py-[2px] text-[11px] font-bold" style={{ background: `${color}1c`, color }}>
      {icon && <Icon path={mdiMapMarker} size={12} color={color} />}
      {children}
    </span>
  )
}

function Row({ icon, k, v }: { icon: string; k: string; v: string }) {
  return (
    <div className="flex items-center gap-2.5">
      <Icon path={icon} size={18} color={PC.grey500} />
      <span className="flex-1" style={{ color: PC.grey600 }}>
        {k}
      </span>
      <span className="font-semibold" style={{ color: PC.charcoal }}>
        {v}
      </span>
    </div>
  )
}
