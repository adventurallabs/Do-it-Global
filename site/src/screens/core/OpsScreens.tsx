import { mdiAlertCircleOutline, mdiBus, mdiCheck, mdiMagnify, mdiPlus, mdiCertificateOutline, mdiCalendarCheckOutline, mdiCashMultiple, mdiBullhornOutline } from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { CoreScreen, IconWell, PK, PageHeader, Pill } from './kit'

/* ---------------------------------------------------------------- */
/*  Roll call — feature_teacher_attendance                            */
/* ---------------------------------------------------------------- */
const ROSTER = [
  ['01', 'Aadhya Raman', 'P'],
  ['02', 'Arjun Kumar', 'P'],
  ['03', 'Bhavya S.', 'A'],
  ['04', 'Dhruv Menon', 'P'],
  ['05', 'Farah Khan', 'P'],
  ['06', 'Gautham R.', 'P'],
  ['07', 'Harini V.', 'L'],
  ['08', 'Ishaan Das', 'P'],
  ['09', 'Janani P.', 'P'],
  ['10', 'Karthik M.', ''],
]

export function RollCallScreen({ marked = 1 }: { marked?: number }) {
  const n = Math.round(ROSTER.length * marked)
  return (
    <CoreScreen>
      <PageHeader title="Roll call · 5-A" sub="Period 3 · Science" actions={false} />
      <div className="px-5 @[700px]:px-8">
        <div className="soft-in flex h-12 items-center gap-2 rounded-[18px] px-4">
          <Icon path={mdiMagnify} size={20} color={PK.hint} />
          <span className="text-[13.5px]" style={{ color: PK.hint }}>
            Search by name, roll or register number
          </span>
        </div>
        <div className="mt-3 flex items-center justify-between text-[12.5px]">
          <span style={{ color: PK.mute }}>
            <b style={{ color: PK.success }}>32 present</b> · <b style={{ color: PK.error }}>2 absent</b> · 1 leave · 1 Not marked
          </span>
          <span className="font-semibold" style={{ color: PK.accent }}>
            Select all
          </span>
        </div>
        <div className="mt-3 grid gap-2.5 @[700px]:grid-cols-2">
          {ROSTER.map(([roll, name, st], i) => {
            const s = i < n ? st : ''
            return (
              <div key={roll} className="soft1 flex items-center gap-3 rounded-[18px] px-3.5 py-2.5">
                <span className="soft-in flex h-9 w-9 items-center justify-center rounded-full text-[12px] font-bold" style={{ color: PK.mute }}>
                  {roll}
                </span>
                <span className="flex-1 text-[14px] font-medium">{name}</span>
                <span className="flex gap-1.5">
                  {(['P', 'A', 'L'] as const).map((k) => {
                    const on = s === k
                    const c = k === 'P' ? PK.success : k === 'A' ? PK.error : PK.warning
                    return (
                      <span
                        key={k}
                        className={`flex h-8 w-8 items-center justify-center rounded-[10px] text-[12px] font-bold transition-all duration-300 ${on ? '' : 'soft2'}`}
                        style={on ? { background: c, color: '#fff', boxShadow: `0 6px 14px -6px ${c}` } : { color: PK.hint }}
                      >
                        {k}
                      </span>
                    )
                  })}
                </span>
              </div>
            )
          })}
        </div>
      </div>
      <div className="gold-btn absolute bottom-5 left-1/2 flex -translate-x-1/2 items-center gap-2 rounded-[20px] px-8 py-3.5 text-[14px] font-semibold">
        <Icon path={mdiCheck} size={18} color="#1a1814" /> Save attendance
      </div>
    </CoreScreen>
  )
}

/* ---------------------------------------------------------------- */
/*  Timetable — feature_admin_timetable, with clash detection         */
/* ---------------------------------------------------------------- */
const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const SUBJ: Record<string, string> = { Eng: '#8B7355', Mat: '#4A5A7A', Sci: '#4E6B5A', Tam: '#C48A3A', Soc: '#6A5A8C', PE: '#7A5A48', Art: '#8A5A4A' }
const GRID = [
  ['Eng', 'Mat', 'Sci', 'Tam', 'Soc', 'PE'],
  ['Mat', 'Eng', 'Tam', 'Sci', 'Art', 'Soc'],
  ['Sci', 'Mat', 'Eng', 'Soc', 'Tam', 'PE'],
  ['Tam', 'Sci', 'Mat', 'Eng', 'Soc', 'Art'],
  ['Eng', 'Mat', 'Sci', 'Tam', 'Soc', 'PE'],
  ['Mat', 'Sci', 'Eng', 'Art', '', ''],
]

export function TimetableAdminScreen() {
  return (
    <CoreScreen>
      <PageHeader title="Timetables" sub="Compose a weekly schedule for this classroom" actions={false} />
      <div className="px-5 @[700px]:px-8">
        <div className="flex items-center gap-2">
          <span className="soft2 rounded-[16px] px-4 py-2 text-[13.5px] font-semibold">Class 5-A</span>
          <Pill color={PK.success}>ACTIVE</Pill>
          <span className="flex-1" />
          <span className="soft-in hidden rounded-[14px] p-1 text-[12.5px] font-semibold @[700px]:flex">
            <span className="px-3 py-1" style={{ color: PK.mute }}>
              Day
            </span>
            <span className="soft2 rounded-[10px] px-3 py-1">Grid</span>
          </span>
        </div>
        <div className="mt-3 flex items-center gap-2.5 rounded-[16px] px-4 py-2.5" style={{ background: '#C8872A1c' }}>
          <Icon path={mdiAlertCircleOutline} size={19} color={PK.warning} />
          <span className="text-[12.5px] font-medium" style={{ color: '#7a5214' }}>
            Fix overlapping periods — Mr. Arun is in 5-A and 6-B at 9:40
          </span>
          <span className="ml-auto text-[12.5px] font-bold" style={{ color: PK.warning }}>
            Fix
          </span>
        </div>
        <div className="soft1 mt-3 overflow-hidden rounded-[22px] p-3">
          <div className="grid grid-cols-[44px_repeat(6,1fr)] gap-1.5 text-center text-[11.5px] @[700px]:grid-cols-[64px_repeat(6,1fr)] @[700px]:gap-2 @[700px]:text-[13px]">
            <span />
            {[1, 2, 3, 4, 5, 6].map((p) => (
              <span key={p} className="py-1 font-semibold" style={{ color: PK.mute }}>
                P{p}
              </span>
            ))}
            {DAYS.map((d, di) => (
              <Row key={d} day={d} cells={GRID[di]} clash={di === 0} />
            ))}
          </div>
        </div>
      </div>
    </CoreScreen>
  )
}

function Row({ day, cells, clash }: { day: string; cells: string[]; clash?: boolean }) {
  return (
    <>
      <span className="flex items-center justify-center font-semibold" style={{ color: PK.mute }}>
        {day}
      </span>
      {cells.map((c, i) => (
        <span
          key={i}
          className="flex h-[44px] items-center justify-center rounded-[12px] font-semibold @[700px]:h-[62px]"
          style={
            c
              ? { background: `${SUBJ[c]}1f`, color: SUBJ[c], outline: clash && i === 1 ? `2px solid ${PK.warning}` : undefined }
              : { border: '1.5px dashed rgba(0,0,0,.08)', color: PK.hint }
          }
        >
          {c || '+'}
        </span>
      ))}
    </>
  )
}

/* ---------------------------------------------------------------- */
/*  Announcements — feature_announcements                              */
/* ---------------------------------------------------------------- */
export function AnnouncementsScreen({ posted = false }: { posted?: boolean }) {
  return (
    <CoreScreen nav="announcements">
      <PageHeader title="Announcements" sub="School notices and your class updates" actions={false} />
      <div className="px-5 @[700px]:grid @[700px]:grid-cols-[1fr_1fr] @[700px]:gap-8 @[700px]:px-8">
        <div className="soft3 rounded-[26px] p-5">
          <div className="soft-in flex rounded-[14px] p-1 text-[12.5px] font-semibold">
            {['School-wide', 'Staff', 'Class 5-A'].map((a, i) => (
              <span key={a} className={`flex-1 rounded-[10px] py-1.5 text-center ${i === 0 ? 'soft2' : ''}`} style={{ color: i === 0 ? PK.ink : PK.mute }}>
                {a}
              </span>
            ))}
          </div>
          <div className="soft-in mt-3 rounded-[14px] px-4 py-3 text-[15px] font-semibold">Parent meeting on Saturday</div>
          <div className="soft-in mt-2 rounded-[14px] px-4 py-3 text-[13px] leading-snug" style={{ color: PK.mute }}>
            Classes 1–5 · 10:00 AM in the main hall. Report cards will be shared with each family.
          </div>
          <div className="mt-3 flex items-center gap-3">
            <span className="flex h-6 w-11 items-center justify-end rounded-full p-0.5" style={{ background: PK.gold }}>
              <span className="h-5 w-5 rounded-full bg-white shadow" />
            </span>
            <div>
              <span className="block text-[13.5px] font-semibold">Mark as important</span>
              <span className="text-[11.5px]" style={{ color: PK.mute }}>
                Highlighted at the top for readers
              </span>
            </div>
          </div>
          <div className="gold-btn mt-4 rounded-[18px] py-3 text-center text-[14px] font-semibold">{posted ? 'Posted' : 'Post announcement'}</div>
        </div>
        <div className="mt-5 flex flex-col gap-3 @[700px]:mt-0">
          {posted && <Notice title="Parent meeting on Saturday" meta="School-wide · just now" important />}
          <Notice title="Science models due Monday" meta="Class 5-A · Yesterday" />
          <Notice title="Staff meeting at 3:30 PM" meta="Staff · Mon" />
          <Notice title="Annual Day registrations open" meta="School-wide · Mon" />
        </div>
      </div>
      <span className="gold-btn absolute bottom-24 right-6 flex h-14 w-14 items-center justify-center rounded-[18px]">
        <Icon path={mdiPlus} size={26} color="#1a1814" />
      </span>
    </CoreScreen>
  )
}

function Notice({ title, meta, important }: { title: string; meta: string; important?: boolean }) {
  return (
    <div className="soft1 flex items-center gap-3 rounded-[20px] p-4" style={important ? { outline: `1.5px solid ${PK.gold}` } : undefined}>
      <IconWell path={mdiBullhornOutline} color={PK.announcement} size={38} />
      <div className="flex-1">
        <span className="block text-[14px] font-semibold">{title}</span>
        <span className="text-[12px]" style={{ color: PK.mute }}>
          {meta}
        </span>
      </div>
      {important && <Pill color={PK.gold}>Important</Pill>}
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  Events — feature_admin_events (compose, categories, certificates) */
/* ---------------------------------------------------------------- */
export function EventsScreen() {
  return (
    <CoreScreen>
      <PageHeader title="Events" sub="Compose an event and notify families" actions={false} />
      <div className="px-5 @[700px]:grid @[700px]:grid-cols-[1.1fr_1fr] @[700px]:gap-8 @[700px]:px-8">
        <div className="soft3 rounded-[26px] p-5">
          <div className="flex items-center gap-3">
            <IconWell path={mdiCalendarCheckOutline} color={PK.event} size={46} />
            <div className="flex-1">
              <span className="block text-[18px] font-bold">Annual Day 2026</span>
              <span className="text-[12.5px]" style={{ color: PK.mute }}>
                Event date · Sat, 18 Oct
              </span>
            </div>
            <Pill color={PK.warning}>Fee payment needed</Pill>
          </div>
          <p className="mb-2 mt-5 text-[12px] font-bold tracking-[0.8px]" style={{ color: PK.mute }}>
            CATEGORIES AND HEADS
          </p>
          {[
            ['Dance', 'Head of Dance · Ms. Kavya', 42],
            ['Drama', 'Head of Drama · Mr. Joseph', 28],
            ['Quiz', 'Head of Quiz · Ms. Revathi', 36],
          ].map(([c, h, n]) => (
            <div key={c as string} className="soft-in mb-2 flex items-center rounded-[14px] px-4 py-2.5">
              <div className="flex-1">
                <span className="block text-[14px] font-semibold">{c}</span>
                <span className="text-[12px]" style={{ color: PK.mute }}>
                  {h}
                </span>
              </div>
              <span className="text-[12.5px] font-semibold" style={{ color: PK.accent }}>
                {n} entries
              </span>
            </div>
          ))}
        </div>
        <div className="mt-5 flex flex-col gap-3 @[700px]:mt-0">
          <div className="soft1 rounded-[22px] p-5">
            <div className="flex items-center gap-3">
              <IconWell path={mdiCertificateOutline} size={42} />
              <div className="flex-1">
                <span className="block text-[15px] font-semibold">Certificates · Inter-house quiz</span>
                <span className="text-[12px]" style={{ color: PK.mute }}>
                  Every layout carries your crest
                </span>
              </div>
            </div>
            <div className="mt-4 flex items-center gap-2">
              <Pill color={PK.success}>Certificates published</Pill>
              <span className="flex-1" />
              <span className="gold-btn rounded-[14px] px-4 py-2 text-[13px] font-semibold">Distribute certificates</span>
            </div>
          </div>
          <div className="soft1 rounded-[22px] p-5">
            <span className="block text-[15px] font-semibold">Sports Day</span>
            <span className="text-[12px]" style={{ color: PK.mute }}>
              Fri, 14 Nov · 6 categories · Families notified
            </span>
          </div>
        </div>
      </div>
    </CoreScreen>
  )
}

/* ---------------------------------------------------------------- */
/*  Fee management — feature_admin_fees                                */
/* ---------------------------------------------------------------- */
const CLASSES = [
  ['LKG', 96],
  ['Class 1', 91],
  ['Class 3', 88],
  ['Class 5', 84],
  ['Class 8', 79],
  ['Class 10', 93],
]

export function FeeManagementScreen({ saved = false }: { saved?: boolean }) {
  return (
    <CoreScreen>
      <PageHeader title="Fee management" sub={`Academic year 2026–27`} actions={false} />
      <div className="px-5 @[700px]:grid @[700px]:grid-cols-[1fr_380px] @[700px]:gap-8 @[700px]:px-8">
        <div>
          <div className="grid grid-cols-2 gap-3">
            <div className="soft1 rounded-[24px] p-4">
              <IconWell path={mdiCashMultiple} color={PK.fee} size={36} />
              <span className="mt-3 block text-[24px] font-extrabold tracking-[-0.6px]">₹38.6L</span>
              <span className="text-[11.5px]" style={{ color: PK.mute }}>
                Collected
              </span>
            </div>
            <div className="soft1 rounded-[24px] p-4">
              <IconWell path={mdiCashMultiple} color={PK.warning} size={36} />
              <span className="mt-3 block text-[24px] font-extrabold tracking-[-0.6px]">{saved ? '₹3.28L' : '₹3.4L'}</span>
              <span className="text-[11.5px]" style={{ color: PK.warning }}>
                Pending
              </span>
            </div>
          </div>
          <div className="soft1 mt-4 rounded-[22px] p-4">
            {CLASSES.map(([c, p]) => (
              <div key={c} className="py-2">
                <div className="flex justify-between text-[13px]">
                  <span className="font-semibold">{c} fees</span>
                  <span style={{ color: PK.mute }}>{c === 'Class 5' && saved ? 87 : p}% paid</span>
                </div>
                <div className="soft-in mt-1.5 h-2 overflow-hidden rounded-full">
                  <div className="h-full rounded-full transition-[width] duration-700" style={{ width: `${c === 'Class 5' && saved ? 87 : p}%`, background: 'linear-gradient(90deg,#3F6B6A,#6FA3A0)' }} />
                </div>
              </div>
            ))}
          </div>
        </div>
        <div className="soft3 mt-4 rounded-[26px] p-5 @[700px]:mt-0">
          <span className="block text-[17px] font-bold">Record payment</span>
          <span className="text-[12.5px]" style={{ color: PK.mute }}>
            Aadhya Raman · Class 5-A
          </span>
          {[
            ['Annual tuition', '₹9,000'],
            ['Transport', '₹3,000'],
          ].map(([k, v]) => (
            <div key={k} className="soft-in mt-3 flex justify-between rounded-[14px] px-4 py-3 text-[14px]">
              <span style={{ color: PK.mute }}>{k}</span>
              <span className="font-semibold">{v}</span>
            </div>
          ))}
          <div className="mt-3 flex gap-2 text-[13px] font-semibold">
            <span className="soft2 flex-1 rounded-[14px] py-2 text-center">Online</span>
            <span className="flex-1 rounded-[14px] py-2 text-center" style={{ color: PK.mute }}>
              Cash
            </span>
          </div>
          <div className="gold-btn mt-4 flex items-center justify-center gap-2 rounded-[18px] py-3 text-[14px] font-semibold">
            {saved && <Icon path={mdiCheck} size={18} color="#1a1814" />}
            {saved ? 'Payment saved' : 'Save payment'}
          </div>
        </div>
      </div>
    </CoreScreen>
  )
}

/* ---------------------------------------------------------------- */
/*  Buses — feature_bus_tracking (admin fleet view)                    */
/* ---------------------------------------------------------------- */
export function BusFleetScreen() {
  const buses = [
    { b: 'Bus 07', r: 'Route 4 · North loop', d: 'Ravi K.', st: 'LIVE', note: 'Near Gandhi Nagar · 32 km/h', c: PK.success },
    { b: 'Bus 03', r: 'Route 2 · Lake side', d: 'Suresh P.', st: 'LIVE', note: 'Near Anna Street · 28 km/h', c: PK.success },
    { b: 'Bus 11', r: 'Route 6 · East link', d: 'Manoj T.', st: 'Trip Ended', note: 'Last seen at School · 7:52 AM', c: PK.mute },
    { b: 'Bus 05', r: 'Route 1 · Town centre', d: 'Anand R.', st: 'Scheduled', note: 'Starts 3:40 PM', c: PK.warning },
  ]
  return (
    <CoreScreen>
      <PageHeader title="Bus Tracking" sub="Fleet & routes" actions={false} />
      <div className="grid gap-3 px-5 @[700px]:grid-cols-2 @[700px]:gap-4 @[700px]:px-8">
        {buses.map((x) => (
          <div key={x.b} className="soft1 rounded-[24px] p-4">
            <div className="flex items-center gap-3">
              <IconWell path={mdiBus} color={PK.bus} size={44} />
              <div className="flex-1">
                <span className="block text-[16px] font-bold">{x.b}</span>
                <span className="text-[12.5px]" style={{ color: PK.mute }}>
                  {x.r}
                </span>
              </div>
              <Pill color={x.c}>{x.st}</Pill>
            </div>
            <div className="soft-in mt-3 flex justify-between rounded-[14px] px-3.5 py-2.5 text-[12.5px]">
              <span style={{ color: PK.mute }}>Driver · {x.d}</span>
              <span className="font-semibold">{x.note}</span>
            </div>
          </div>
        ))}
      </div>
      <span className="gold-btn absolute bottom-6 right-6 flex items-center gap-2 rounded-[18px] px-5 py-3 text-[13.5px] font-semibold">
        <Icon path={mdiPlus} size={20} color="#1a1814" /> Add bus
      </span>
    </CoreScreen>
  )
}
