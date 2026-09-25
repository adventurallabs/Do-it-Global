import {
  mdiAlertCircleOutline,
  mdiBus,
  mdiBullhornOutline,
  mdiCalendarOutline,
  mdiCheckDecagram,
  mdiClipboardTextOutline,
  mdiInformationOutline,
  mdiPaperclip,
  mdiPartyPopper,
  mdiSchoolOutline,
  mdiSend,
  mdiTimerOutline,
  mdiWalletOutline,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { DATE, SCHOOL, STUDENT } from '../../data/sample'
import { AppBar, Avatar, Badge, Card, ConnectScreen, IconTile, PC, StatusBar, heroGradient } from './kit'

/* ---------------------------------------------------------------- */
/*  Results — the "Statement of marks" from result_statement_screen  */
/* ---------------------------------------------------------------- */
const MARKS = [
  { s: 'English', m: 88 },
  { s: 'Tamil', m: 91 },
  { s: 'Mathematics', m: 95 },
  { s: 'Science', m: 86 },
  { s: 'Social Science', m: 84 },
]

export function ResultsScreen() {
  const total = MARKS.reduce((a, b) => a + b.m, 0)
  return (
    <ConnectScreen>
      <AppBar title="Results" />
      <div className="px-4">
        <Card luminous className="mb-3 flex items-center gap-3">
          <IconTile path={mdiSchoolOutline} color={PC.primaryBlue} />
          <div className="flex-1">
            <span className="block text-[16px] font-semibold" style={{ color: PC.charcoal }}>
              Quarterly exams
            </span>
            <span className="text-[12.5px]" style={{ color: PC.grey500 }}>
              5 subjects
            </span>
          </div>
          <Badge tone="success">All results are out</Badge>
        </Card>

        <Card className="!p-0 overflow-hidden">
          <div className="px-4 pb-3 pt-4 text-center">
            <span className="pc-display block text-[18px] font-semibold" style={{ color: PC.charcoal }}>
              Statement of marks
            </span>
            <span className="text-[12px]" style={{ color: PC.grey500 }}>
              {SCHOOL.name} · {STUDENT.year}
            </span>
          </div>
          <div className="grid grid-cols-2 gap-x-3 gap-y-1.5 border-y px-4 py-3 text-[12px]" style={{ borderColor: PC.grey200 }}>
            {[
              ['Name', STUDENT.name],
              ['Register no.', STUDENT.registerNo],
              ['Class & section', `${STUDENT.className}-${STUDENT.section}`],
              ['Roll no.', STUDENT.rollNo],
            ].map(([k, v]) => (
              <span key={k}>
                <span style={{ color: PC.grey500 }}>{k} </span>
                <span className="font-semibold" style={{ color: PC.charcoal }}>
                  {v}
                </span>
              </span>
            ))}
          </div>
          <table className="w-full text-[12.5px]" style={{ color: PC.charcoal }}>
            <thead>
              <tr className="text-[11px] uppercase tracking-[0.5px]" style={{ color: PC.grey500, background: '#F2F7FE' }}>
                <th className="py-2 pl-4 text-left font-semibold">S.No</th>
                <th className="py-2 text-left font-semibold">Subject</th>
                <th className="py-2 font-semibold">Max</th>
                <th className="py-2 font-semibold">Pass</th>
                <th className="py-2 font-semibold">Marks</th>
                <th className="py-2 pr-4 font-semibold">Result</th>
              </tr>
            </thead>
            <tbody>
              {MARKS.map((r, i) => (
                <tr key={r.s} className="border-t" style={{ borderColor: '#EEF4FB' }}>
                  <td className="py-2.5 pl-4">{i + 1}</td>
                  <td className="py-2.5 font-medium">{r.s}</td>
                  <td className="py-2.5 text-center">100</td>
                  <td className="py-2.5 text-center">35</td>
                  <td className="py-2.5 text-center font-semibold">{r.m}</td>
                  <td className="py-2.5 pr-4 text-center text-[11px] font-bold" style={{ color: PC.success }}>
                    PASS
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="grid grid-cols-3 border-t text-center" style={{ borderColor: PC.grey200 }}>
            {[
              ['Total', `${total} / 500`],
              ['Percentage', `${((total / 500) * 100).toFixed(1)}%`],
              ['Overall result', 'PASS'],
            ].map(([k, v], i) => (
              <div key={k} className="py-3" style={{ borderLeft: i ? `1px solid ${PC.grey200}` : undefined }}>
                <span className="block text-[11px]" style={{ color: PC.grey500 }}>
                  {k}
                </span>
                <span className="text-[15px] font-bold" style={{ color: i === 2 ? PC.success : PC.charcoal }}>
                  {v}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </ConnectScreen>
  )
}

/* ---------------------------------------------------------------- */
/*  School life — timetable_screen                                   */
/* ---------------------------------------------------------------- */
const PERIODS = [
  { n: 1, s: 'English', t: '9:00 – 9:40', who: 'Ms. Anita', st: 'done' },
  { n: 2, s: 'Mathematics', t: '9:40 – 10:20', who: 'Mr. Arun', st: 'done' },
  { n: 3, s: 'Science', t: '10:30 – 11:10', who: 'Ms. Kavya', st: 'now' },
  { n: 4, s: 'Tamil', t: '11:10 – 11:50', who: 'Mr. Senthil', st: 'next' },
  { n: 5, s: 'Social Science', t: '12:30 – 1:10', who: 'Ms. Revathi', st: 'cover' },
  { n: 6, s: 'Physical Education', t: '1:10 – 1:50', who: 'Mr. Joseph', st: '' },
]

export function TimetableScreen() {
  return (
    <ConnectScreen>
      <AppBar title="Timetable" trailing={<span className="mr-3 text-[13px] font-semibold" style={{ color: PC.primaryBlue }}>Full week</span>} />
      <div className="px-4">
        <div className="mb-4 flex justify-between">
          {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) => (
            <span
              key={d}
              className="flex h-[52px] w-[52px] flex-col items-center justify-center rounded-[16px] text-[13px] font-semibold"
              style={d === 'Fri' ? { background: PC.primaryBlue, color: '#fff', boxShadow: '0 10px 20px -10px rgba(47,107,255,.8)' } : { background: 'rgba(255,255,255,.8)', color: PC.grey600 }}
            >
              {d}
            </span>
          ))}
        </div>
        <div className="mb-2 flex items-end justify-between">
          <span className="pc-display text-[20px] font-semibold" style={{ color: PC.charcoal }}>
            Today's classes
          </span>
          <span className="text-[12.5px]" style={{ color: PC.grey500 }}>
            6 periods
          </span>
        </div>
        <div className="flex flex-col gap-2">
          {PERIODS.map((p) => {
            const now = p.st === 'now'
            return (
              <Card
                key={p.n}
                className="flex items-center gap-3 !py-3"
                style={now ? { borderColor: 'rgba(47,107,255,.45)', boxShadow: '0 14px 30px -14px rgba(47,107,255,.5)' } : { opacity: p.st === 'done' ? 0.55 : 1 }}
              >
                <span className="w-7 text-center text-[13px] font-bold" style={{ color: now ? PC.primaryBlue : PC.grey400 }}>
                  {p.n}
                </span>
                <div className="min-w-0 flex-1">
                  <span className="block text-[15px] font-semibold" style={{ color: PC.charcoal }}>
                    {p.s}
                  </span>
                  <span className="text-[12px]" style={{ color: PC.grey500 }}>
                    {p.t} · {p.who}
                  </span>
                </div>
                {p.st === 'now' && <Badge tone="info">Now</Badge>}
                {p.st === 'next' && <Badge tone="success">Next</Badge>}
                {p.st === 'cover' && <Badge tone="warning">Cover</Badge>}
              </Card>
            )
          })}
        </div>
      </div>
    </ConnectScreen>
  )
}

/* ---------------------------------------------------------------- */
/*  Messages — message_screen with its quick actions                 */
/* ---------------------------------------------------------------- */
export function MessagesScreen({ leaveStatus = 'Under Review' }: { leaveStatus?: string }) {
  return (
    <ConnectScreen>
      <AppBar title={`${STUDENT.first}'s Teacher`} trailing={<span className="mr-2"><Icon path={mdiInformationOutline} size={22} color={PC.charcoal} /></span>} />
      <div className="flex gap-2 px-4">
        {[
          { l: 'Request Leave', p: mdiCalendarOutline, c: PC.primaryBlue },
          { l: 'Inform Leave', p: mdiAlertCircleOutline, c: PC.heart },
          { l: 'Inform Late', p: mdiTimerOutline, c: PC.warning },
        ].map((a) => (
          <span key={a.l} className="flex flex-1 items-center justify-center gap-1.5 rounded-[14px] border bg-white/85 py-2.5 text-[12.5px] font-semibold" style={{ borderColor: `${a.c}33`, color: PC.charcoal }}>
            <Icon path={a.p} size={16} color={a.c} />
            {a.l}
          </span>
        ))}
      </div>
      <div className="mt-4 flex flex-col gap-3 px-4">
        <p className="text-center text-[11.5px] font-medium" style={{ color: PC.grey500 }}>
          Yesterday
        </p>
        <Bubble from="teacher" text="Good evening! A reminder that the science models are due on Monday." time="6:12 PM" />
        <Bubble from="parent" text="Thank you, ma’am. She is almost done with it." time="6:20 PM" />
        <p className="text-center text-[11.5px] font-medium" style={{ color: PC.grey500 }}>
          Today
        </p>
        <Card className="self-end !rounded-[20px] !rounded-br-[6px] !p-3.5" style={{ width: 270, background: '#fff' }}>
          <div className="flex items-center gap-2">
            <Icon path={mdiCalendarOutline} size={16} color={PC.primaryBlue} />
            <span className="text-[14px] font-semibold" style={{ color: PC.charcoal }}>
              Request Leave
            </span>
            <span className="ml-auto">
              <Badge tone={leaveStatus === 'Approved' ? 'success' : 'warning'}>{leaveStatus}</Badge>
            </span>
          </div>
          <div className="mt-2.5 space-y-1 text-[12.5px]" style={{ color: PC.grey600 }}>
            <p>
              <span style={{ color: PC.grey500 }}>From</span> Mon, 29 Sep <span style={{ color: PC.grey500 }}>To</span> Tue, 30 Sep · 2 days
            </p>
            <p>
              <span style={{ color: PC.grey500 }}>Reason for leave:</span> Family function
            </p>
          </div>
        </Card>
        <Bubble from="teacher" text="Noted. I’ll share the homework for those days in the diary." time="8:05 AM" />
      </div>
      <div className="absolute inset-x-3 bottom-4 flex items-center gap-2 rounded-[26px] border bg-white/95 p-1.5 pl-3" style={{ borderColor: PC.grey200 }}>
        <Icon path={mdiPaperclip} size={22} color={PC.grey500} />
        <span className="flex-1 text-[14.5px]" style={{ color: PC.grey400 }}>
          Write a message…
        </span>
        <span className="flex h-10 w-10 items-center justify-center rounded-full" style={{ background: PC.primaryBlue }}>
          <Icon path={mdiSend} size={19} color="#fff" />
        </span>
      </div>
    </ConnectScreen>
  )
}

function Bubble({ from, text, time }: { from: 'teacher' | 'parent'; text: string; time: string }) {
  const mine = from === 'parent'
  return (
    <div className={`max-w-[270px] rounded-[20px] px-3.5 py-2.5 text-[14px] leading-snug ${mine ? 'self-end rounded-br-[6px] text-white' : 'self-start rounded-bl-[6px] bg-white'}`} style={mine ? { background: PC.primaryBlue } : { color: PC.charcoal, boxShadow: '0 8px 20px -14px rgba(16,32,55,.4)' }}>
      {text}
      <span className={`mt-1 block text-right text-[10.5px] ${mine ? 'text-white/70' : ''}`} style={mine ? undefined : { color: PC.grey400 }}>
        {time}
      </span>
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  Digital student ID — digital_id_card                              */
/* ---------------------------------------------------------------- */
export function DigitalIdScreen() {
  return (
    <div className="pc absolute inset-0 overflow-hidden" style={{ background: 'linear-gradient(160deg,#0b1830,#07111F)' }}>
      <StatusBar dark />
      <div className="absolute inset-x-5 top-[88px] overflow-hidden rounded-[28px] bg-white shadow-[0_40px_80px_-20px_rgba(0,0,0,.6)]">
        <div className="relative px-5 pb-12 pt-5 text-white" style={{ background: heroGradient }}>
          <div className="flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-full bg-white/15 text-[13px] font-bold">{SCHOOL.short}</span>
            <div>
              <span className="block text-[16px] font-semibold">{SCHOOL.name}</span>
              <span className="text-[12px] text-white/70">{SCHOOL.place}</span>
            </div>
          </div>
          <span className="mt-4 inline-block rounded-full bg-white/15 px-3 py-1 text-[10.5px] font-bold tracking-[1.6px]">STUDENT IDENTITY CARD</span>
        </div>
        <div className="relative z-10 -mt-10 flex flex-col items-center px-5 pb-5">
          <Avatar initials={STUDENT.initials} size={84} ring />
          <span className="pc-display mt-3 text-[22px] font-semibold" style={{ color: PC.charcoal }}>
            {STUDENT.name}
          </span>
          <span className="text-[13px]" style={{ color: PC.grey500 }}>
            Class {STUDENT.className}-{STUDENT.section} · {STUDENT.year}
          </span>
          <span className="mt-2 inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-[11.5px] font-semibold" style={{ background: PC.successSoft, color: PC.successOn }}>
            <Icon path={mdiCheckDecagram} size={14} color={PC.success} /> Verified Student
          </span>
          <div className="mt-4 grid w-full grid-cols-2 gap-x-4 gap-y-3 rounded-[18px] p-4 text-[12px]" style={{ background: '#F4F8FD' }}>
            {[
              ['Admission no.', STUDENT.admissionNo],
              ['Roll no.', STUDENT.rollNo],
              ['Blood group', STUDENT.blood],
              ['Valid until', '2027'],
            ].map(([k, v]) => (
              <div key={k}>
                <span className="block" style={{ color: PC.grey500 }}>
                  {k}
                </span>
                <span className="text-[14px] font-semibold" style={{ color: PC.charcoal }}>
                  {v}
                </span>
              </div>
            ))}
          </div>
          <div className="mt-4 flex items-center gap-4">
            <QrPattern />
            <span className="text-[12px] leading-snug" style={{ color: PC.grey500 }}>
              Verification code
              <br />
              <span className="font-mono text-[11px]">SPS · {STUDENT.admissionNo}</span>
            </span>
          </div>
        </div>
      </div>
      <p className="absolute inset-x-0 bottom-10 text-center text-[13px] font-semibold tracking-[1.4px] text-white/70">CLOSE</p>
    </div>
  )
}

/** A decorative, non-scannable QR-style pattern. */
function QrPattern() {
  const n = 21
  const cells: boolean[] = []
  let seed = 7
  for (let i = 0; i < n * n; i++) {
    seed = (seed * 16807) % 2147483647
    cells.push(seed % 3 === 0)
  }
  const finder = (x: number, y: number) => {
    const inBox = (ox: number, oy: number) => x >= ox && x < ox + 7 && y >= oy && y < oy + 7
    for (const [ox, oy] of [
      [0, 0],
      [n - 7, 0],
      [0, n - 7],
    ]) {
      if (inBox(ox, oy)) {
        const dx = x - ox
        const dy = y - oy
        return dx === 0 || dx === 6 || dy === 0 || dy === 6 || (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4) ? 1 : 0
      }
    }
    return -1
  }
  return (
    <svg viewBox={`0 0 ${n} ${n}`} className="h-[84px] w-[84px]" shapeRendering="crispEdges" aria-hidden>
      {cells.map((on, i) => {
        const x = i % n
        const y = Math.floor(i / n)
        const f = finder(x, y)
        const fill = f === -1 ? on : f === 1
        return fill ? <rect key={i} x={x} y={y} width={1} height={1} fill={PC.charcoal} /> : null
      })}
    </svg>
  )
}

/* ---------------------------------------------------------------- */
/*  Notifications                                                     */
/* ---------------------------------------------------------------- */
export const NOTIFICATIONS = [
  { p: mdiClipboardTextOutline, c: PC.primaryBlue, t: 'New homework · Mathematics', s: 'Fractions — worksheet 4 · Due today', time: '8:02 AM', unread: true },
  { p: mdiBus, c: PC.leafGreen, t: 'Trip Started', s: 'Bus 07 · Route 4 is on the way', time: '7:18 AM', unread: true },
  { p: mdiSchoolOutline, c: '#7C3AED', t: 'Results · Quarterly exams', s: 'All results are out', time: 'Yesterday', unread: true },
  { p: mdiBullhornOutline, c: PC.warning, t: 'Parent meeting', s: 'Saturday, 10:00 AM · Main hall', time: 'Yesterday' },
  { p: mdiWalletOutline, c: PC.heart, t: 'Fee due', s: '₹12,000 remaining · Due in 6 days', time: 'Mon' },
  { p: mdiPartyPopper, c: PC.heart, t: 'Annual Day', s: 'Registrations are open for Class 5', time: 'Mon' },
]

export function NotificationsScreen({ highlight = -1 }: { highlight?: number }) {
  return (
    <ConnectScreen>
      <AppBar title="Notifications" trailing={<span className="mr-3 text-[12.5px] font-semibold" style={{ color: PC.primaryBlue }}>3 new school updates</span>} />
      <div className="flex flex-col gap-2.5 px-4">
        {NOTIFICATIONS.map((n, i) => (
          <Card
            key={n.t}
            className="flex items-center gap-3 !py-3 transition-all duration-500"
            style={i === highlight ? { borderColor: 'rgba(47,107,255,.5)', boxShadow: '0 16px 32px -14px rgba(47,107,255,.55)', transform: 'scale(1.02)' } : undefined}
          >
            <IconTile path={n.p} color={n.c} />
            <div className="min-w-0 flex-1">
              <span className="block truncate text-[14.5px] font-semibold" style={{ color: PC.charcoal }}>
                {n.t}
              </span>
              <span className="block truncate text-[12.5px]" style={{ color: PC.grey500 }}>
                {n.s}
              </span>
            </div>
            <div className="flex flex-col items-end gap-1.5">
              <span className="text-[11px]" style={{ color: PC.grey400 }}>
                {n.time}
              </span>
              {n.unread && <span className="h-2 w-2 rounded-full" style={{ background: PC.primaryBlue }} />}
            </div>
          </Card>
        ))}
        <p className="mt-2 text-center text-[12px]" style={{ color: PC.grey400 }}>
          Updated {DATE.short} · 8:05 AM
        </p>
      </div>
    </ConnectScreen>
  )
}

