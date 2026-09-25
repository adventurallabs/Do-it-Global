import {
  mdiAccountGroupOutline,
  mdiBadgeAccountHorizontalOutline,
  mdiBullhornOutline,
  mdiBus,
  mdiCalendarCheckOutline,
  mdiCalendarRemoveOutline,
  mdiCalendarWeek,
  mdiCashMultiple,
  mdiCertificateOutline,
  mdiChevronRight,
  mdiClipboardCheckOutline,
  mdiClipboardClockOutline,
  mdiFileQuestionOutline,
  mdiAccountCheckOutline,
  mdiSchoolOutline,
  mdiTimelineOutline,
  mdiAccountOffOutline,
  mdiStarOutline,
  mdiNoteTextOutline,
  mdiPencilOutline,
  mdiFormatListChecks,
  mdiWhiteBalanceSunny,
  mdiCheckDecagram,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { ClockCard, CoreScreen, IconWell, PK, PageHeader, Pill } from './kit'

/* ---------------------------------------------------------------- */
/*  Admin — admin_main_screen "Today's school"                        */
/* ---------------------------------------------------------------- */
const MANAGEMENT = [
  { t: 'Classrooms', s: 'LKG to 12th · sections', p: mdiSchoolOutline, c: PK.classroom },
  { t: 'Staff', s: 'Teaching & office', p: mdiBadgeAccountHorizontalOutline, c: PK.teacher },
  { t: 'Students', s: 'Records & placement', p: mdiAccountGroupOutline, c: PK.student },
  { t: 'Attendance', s: 'Today & absences', p: mdiClipboardCheckOutline, c: PK.attendance },
  { t: 'Leave & cover', s: 'Approve & substitute', p: mdiCalendarRemoveOutline, c: PK.leave },
  { t: 'Student leave', s: 'Parent requests', p: mdiBadgeAccountHorizontalOutline, c: PK.leave },
  { t: 'Academic year', s: 'Promote · retain', p: mdiTimelineOutline, c: PK.academics },
  { t: 'Exams', s: 'Timetables & publish', p: mdiFileQuestionOutline, c: PK.exam },
  { t: 'Results', s: 'Marks & grades by class', p: mdiClipboardCheckOutline, c: PK.academics },
  { t: 'Admissions', s: 'Enquiry to record', p: mdiAccountCheckOutline, c: PK.admission },
  { t: 'Announcements', s: 'Staff & school', p: mdiBullhornOutline, c: PK.announcement },
  { t: 'Events', s: 'School calendar', p: mdiCalendarCheckOutline, c: PK.event },
  { t: 'Fees', s: 'Paid & pending', p: mdiCashMultiple, c: PK.fee },
  { t: 'Buses', s: 'Fleet & routes', p: mdiBus, c: PK.bus },
  { t: 'Discontinued', s: 'Left · 30-day archive', p: mdiAccountOffOutline, c: PK.leave },
  { t: 'Graduated', s: 'Finished · archive', p: mdiCertificateOutline, c: PK.academics },
]

export function AdminDashboardScreen() {
  return (
    <CoreScreen>
      <PageHeader title="Today's school" />
      <div className="h-full overflow-hidden @[700px]:grid @[700px]:grid-cols-[400px_1fr] @[700px]:gap-8 @[700px]:px-8">
        <div>
          <ClockCard subtitle="Good morning, Admin" title="Stay on top of campus" compact />
          <div className="grid grid-cols-2 gap-3 px-5 @[700px]:px-0">
            <Kpi label="Students" value="1,248" icon={mdiSchoolOutline} />
            <Kpi label="Staff present today" value="58/62" icon={mdiBadgeAccountHorizontalOutline} chevron />
            <Kpi label="2 classes not marked yet" value="94.2%" icon={mdiClipboardClockOutline} tint={PK.warning} chevron />
            <Kpi label="Pending fees" value="₹3.4L" icon={mdiCashMultiple} />
          </div>
          <p className="mb-2 mt-5 px-5 text-[15px] font-semibold @[700px]:px-0">Needs attention</p>
          <div className="soft1 mx-5 rounded-[16px] py-1 @[700px]:mx-0">
            {['3 parent leave requests to review', 'Class 7-B attendance not taken', '2 fee payments to verify'].map((a, i) => (
              <div key={a} className="flex items-center gap-3 px-4 py-2.5" style={{ borderTop: i ? '1px solid rgba(0,0,0,.06)' : undefined }}>
                <span className="h-2 w-2 rounded-full" style={{ background: PK.warning }} />
                <span className="flex-1 text-[13.5px] font-medium">{a}</span>
                <Icon path={mdiChevronRight} size={18} color={PK.hint} />
              </div>
            ))}
          </div>
        </div>
        <div className="hidden @[700px]:block">
          <p className="mb-3 mt-2 text-[15px] font-semibold">Management</p>
          <div className="grid grid-cols-4 gap-[14px]">
            {MANAGEMENT.map((m) => (
              <div key={m.t} className="soft1 flex h-[132px] flex-col justify-between rounded-[24px] p-4">
                <IconWell path={m.p} color={m.c} size={40} />
                <div>
                  <span className="block text-[14.5px] font-semibold leading-tight">{m.t}</span>
                  <span className="text-[11.5px]" style={{ color: PK.mute }}>
                    {m.s}
                  </span>
                </div>
              </div>
            ))}
          </div>
          <p className="mb-3 mt-5 text-[15px] font-semibold">Quick actions</p>
          <div className="flex gap-2.5">
            {['Attendance', 'Announcement', 'Add student', 'Record fee'].map((c) => (
              <span key={c} className="soft2 rounded-[20px] px-4 py-2.5 text-[13px] font-medium">
                {c}
              </span>
            ))}
          </div>
        </div>
      </div>
    </CoreScreen>
  )
}

function Kpi({ label, value, icon, tint, chevron }: { label: string; value: string; icon: string; tint?: string; chevron?: boolean }) {
  return (
    <div className="soft1 rounded-[26px] px-4 pb-3.5 pt-4">
      <div className="flex items-center">
        <IconWell path={icon} color={tint ?? PK.gold} size={36} />
        <span className="flex-1" />
        {chevron && <Icon path={mdiChevronRight} size={17} color={PK.mute} />}
      </div>
      <span className="mt-3 block text-[24px] font-extrabold tracking-[-0.6px]" style={{ color: PK.inkDeep }}>
        {value}
      </span>
      <span className="block text-[11.5px] leading-tight" style={{ color: tint ?? PK.mute, fontWeight: tint ? 600 : 400 }}>
        {label}
      </span>
    </div>
  )
}

/* ---------------------------------------------------------------- */
/*  Teacher — teacher_dashboard_screen "Home"                         */
/* ---------------------------------------------------------------- */
const SCHEDULE = [
  { n: 'Period 1', c: '5-A', t: '9:00 – 9:40 AM', st: 'Taken' },
  { n: 'Period 2', c: '6-B', t: '9:40 – 10:20 AM', st: 'Taken' },
  { n: 'Period 3', c: '5-A', t: '10:30 – 11:10 AM', st: 'Now' },
  { n: 'Period 5', c: '4-C', t: '12:30 – 1:10 PM', st: 'Upcoming' },
  { n: 'Period 6', c: '6-B', t: '1:10 – 1:50 PM', st: 'Upcoming' },
]

export function TeacherHomeScreen() {
  const tone = (s: string) => (s === 'Now' ? PK.gold : s === 'Taken' ? PK.success : PK.mute)
  return (
    <CoreScreen nav="home">
      <PageHeader title="Home" />
      <div className="@[700px]:grid @[700px]:grid-cols-[400px_1fr] @[700px]:gap-8 @[700px]:px-8">
        <div>
          <ClockCard subtitle="Good morning" title="Priya Nair" compact />
          <div className="flex gap-3 overflow-hidden px-5 @[700px]:px-0">
            {[
              ['Assigned today', '5'],
              ['Attended today', '2'],
              ['Ended today', '0'],
            ].map(([l, v]) => (
              <span key={l} className="soft2 flex-1 rounded-[20px] px-3 py-2.5">
                <span className="block text-[20px] font-extrabold">{v}</span>
                <span className="text-[11px]" style={{ color: PK.mute }}>
                  {l}
                </span>
              </span>
            ))}
          </div>
          <div className="soft1 mx-5 mt-4 flex items-center gap-3 rounded-[24px] p-4 @[700px]:mx-0">
            <IconWell path={mdiFormatListChecks} size={42} />
            <div className="flex-1">
              <span className="block text-[15px] font-semibold">Class 5-A · Attendance</span>
              <span className="text-[12px]" style={{ color: PK.mute }}>
                Not taken yet today
              </span>
            </div>
            <span className="gold-btn rounded-[16px] px-4 py-2.5 text-[13px] font-semibold">Take attendance</span>
          </div>
        </div>
        <div className="mt-5 px-5 @[700px]:mt-2 @[700px]:px-0">
          <div className="mb-3 flex items-center justify-between">
            <span className="text-[17px] font-bold">Today's schedule</span>
            <span className="text-[13px] font-semibold" style={{ color: PK.hint }}>
              5 periods · <span style={{ color: PK.accent }}>My week</span>
            </span>
          </div>
          <div className="flex flex-col gap-3">
            {SCHEDULE.map((p) => {
              const now = p.st === 'Now'
              return (
                <div key={p.n + p.c} className={`${now ? 'soft3' : 'soft1'} rounded-[22px] p-4`} style={{ opacity: p.st === 'Taken' ? 0.72 : 1 }}>
                  <div className="flex items-center gap-3">
                    <span className="soft-in flex h-11 w-11 items-center justify-center rounded-[14px] text-[13px] font-bold" style={{ color: tone(p.st) }}>
                      {p.c}
                    </span>
                    <div className="flex-1">
                      <span className="block text-[15px] font-semibold">
                        {p.n} · Science
                      </span>
                      <span className="text-[12px]" style={{ color: PK.mute }}>
                        {p.t}
                      </span>
                    </div>
                    <Pill color={tone(p.st)}>{p.st}</Pill>
                  </div>
                  {now && (
                    <div className="mt-3 flex gap-2">
                      <span className="gold-btn flex-1 rounded-[16px] py-2.5 text-center text-[13px] font-semibold">Start class & roll call</span>
                      <span className="soft2 rounded-[16px] px-4 py-2.5 text-[13px] font-medium">Assign homework</span>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </CoreScreen>
  )
}

/* ---------------------------------------------------------------- */
/*  Classroom tools — my_classroom_screen + class_update_screen       */
/* ---------------------------------------------------------------- */
export function ClassroomScreen({ shared = false }: { shared?: boolean }) {
  const tools = [
    { l: 'Attendance', p: mdiClipboardCheckOutline, c: PK.attendance },
    { l: 'Marks', p: mdiFileQuestionOutline, c: PK.exam },
    { l: 'Stars & progress', p: mdiStarOutline, c: PK.gold },
    { l: "Today's update", p: mdiWhiteBalanceSunny, c: PK.announcement },
    { l: 'Timetable', p: mdiCalendarWeek, c: PK.classroom },
    { l: 'Diary note', p: mdiNoteTextOutline, c: PK.event },
  ]
  return (
    <CoreScreen nav="classes">
      <PageHeader title="Class 5-A" sub="Class teacher · 36 students" actions={false} />
      <div className="px-5 @[700px]:grid @[700px]:grid-cols-[400px_1fr] @[700px]:gap-8 @[700px]:px-8">
        <div className="grid grid-cols-3 gap-3 @[700px]:grid-cols-2">
          {tools.map((t) => (
            <div key={t.l} className="soft1 flex flex-col items-start gap-3 rounded-[22px] p-3.5">
              <IconWell path={t.p} color={t.c} size={38} />
              <span className="text-[13px] font-semibold leading-tight">{t.l}</span>
            </div>
          ))}
        </div>
        <div className="soft1 mt-5 rounded-[26px] p-5 @[700px]:mt-0">
          <div className="flex items-center justify-between">
            <span className="text-[17px] font-bold">Today · Class 5-A</span>
            <Icon path={mdiPencilOutline} size={20} color={PK.mute} />
          </div>
          <p className="mt-1 text-[12.5px]" style={{ color: PK.mute }}>
            What the class learned today — parents see it on their Today screen.
          </p>
          <p className="mb-2 mt-4 text-[12px] font-bold tracking-[0.8px]" style={{ color: PK.mute }}>
            LEARNED TODAY
          </p>
          <div className="flex flex-col gap-2">
            {[
              ['Science', 'Parts of a plant — roots, stem and leaves'],
              ['Mathematics', 'Equivalent fractions with pictures'],
            ].map(([s, d]) => (
              <div key={s} className="soft-in rounded-[14px] px-3.5 py-2.5">
                <span className="block text-[13.5px] font-semibold">{s}</span>
                <span className="text-[12.5px]" style={{ color: PK.mute }}>
                  {d}
                </span>
              </div>
            ))}
          </div>
          <p className="mb-2 mt-4 text-[12px] font-bold tracking-[0.8px]" style={{ color: PK.mute }}>
            GROWING IN
          </p>
          <div className="flex gap-2">
            {['Teamwork', 'Curiosity'].map((s) => (
              <span key={s} className="soft2 rounded-full px-3.5 py-1.5 text-[12.5px] font-medium">
                {s}
              </span>
            ))}
            <span className="rounded-full px-3 py-1.5 text-[12.5px] font-medium" style={{ color: PK.accent }}>
              + Add skill
            </span>
          </div>
          <div className="gold-btn mt-5 flex items-center justify-center gap-2 rounded-[18px] py-3 text-[14px] font-semibold">
            {shared && <Icon path={mdiCheckDecagram} size={18} color="#1a1814" />}
            {shared ? 'Update shared with parents' : 'Share with parents'}
          </div>
        </div>
      </div>
    </CoreScreen>
  )
}
