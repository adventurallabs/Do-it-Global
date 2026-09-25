import {
  mdiBookOpenVariant,
  mdiBus,
  mdiCalendarWeek,
  mdiCheck,
  mdiChevronDown,
  mdiMagnify,
  mdiClipboardTextOutline,
  mdiCalendarMonthOutline,
  mdiChevronLeft,
  mdiChevronRight,
  mdiNoteTextOutline,
  mdiBullhornOutline,
  mdiTrophyOutline,
  mdiPartyPopper,
  mdiCalculatorVariantOutline,
  mdiFlaskOutline,
  mdiEarth,
  mdiTranslate,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { DATE, STUDENT } from '../../data/sample'
import { AppBar, Avatar, Badge, Bell, Card, ConnectScreen, IconTile, PC, SectionHeader, heroGradient, type TabId } from './kit'

/** Strings for the Today screen, straight from lib/l10n/app_en.arb and app_ta.arb. */
const L = {
  en: {
    greeting: 'Good morning',
    title: `${STUDENT.first}'s School Day`,
    today: 'Today at school',
    timetable: 'Timetable',
    events: 'Events',
    bus: 'School bus',
    periods: "Today's classes",
    now: 'Now',
    next: 'Next',
    hwStatus: 'Homework Status',
    seeAll: 'See all homework',
    dueToday: 'Due today',
    date: `${DATE.weekday.toUpperCase()}, ${DATE.month.toUpperCase()} ${DATE.day}`,
    tabs: undefined as Partial<Record<TabId, string>> | undefined,
  },
  ta: {
    greeting: 'காலை வணக்கம்',
    title: `${STUDENT.first}-இன் பள்ளி நாள்`,
    today: 'இன்று பள்ளியில்',
    timetable: 'கால அட்டவணை',
    events: 'நிகழ்வுகள்',
    bus: 'பள்ளிப் பேருந்து',
    periods: 'இன்றைய வகுப்புகள்',
    now: 'இப்போது',
    next: 'அடுத்து',
    hwStatus: 'வீட்டுப்பாட நிலை',
    seeAll: 'அனைத்து வீட்டுப்பாடமும்',
    dueToday: 'இன்று கடைசி நாள்',
    date: 'வெள்ளி, செப்டம்பர் 25',
    tabs: { today: 'இன்று', diary: 'டைரி', messages: 'செய்திகள்', progress: 'முன்னேற்றம்', profile: 'சுயவிவரம்' },
  },
}

export function TodayScreen({ lang = 'en' }: { lang?: 'en' | 'ta' }) {
  const t = L[lang]
  return (
    <ConnectScreen nav="today" navLabels={t.tabs}>
      <div className="px-4 pt-1">
        <div className="flex items-center justify-between">
          <span className="pc-display text-[24px] font-semibold tracking-[-0.3px]" style={{ color: PC.charcoal }}>
            {t.greeting}
          </span>
          <Bell count={3} />
        </div>
        <div className="mt-2 flex items-center gap-2.5">
          <Avatar initials={STUDENT.initials} size={36} ring />
          <span className="text-[15px] font-semibold" style={{ color: PC.charcoal }}>
            {STUDENT.name}
          </span>
          <span className="rounded-full bg-white/80 px-2 py-0.5 text-[12px] font-medium" style={{ color: PC.grey600 }}>
            {STUDENT.className}-{STUDENT.section}
          </span>
          <Icon path={mdiChevronDown} size={20} color={PC.grey500} />
        </div>
        <p className="mb-3 mt-3 text-[12px] font-medium tracking-[1.1px]" style={{ color: PC.grey600 }}>
          {t.date}
        </p>

        {/* SchoolDayHeroCard */}
        <div className="relative overflow-hidden rounded-[32px] p-6" style={{ background: heroGradient, boxShadow: '0 16px 36px -10px rgba(47,107,255,.45)' }}>
          <span className="absolute -right-[18px] -top-[24px] h-[120px] w-[120px] rounded-full" style={{ background: 'rgba(62,198,255,.16)' }} />
          <span className="absolute -bottom-[30px] right-[28px] h-[90px] w-[90px] rounded-full" style={{ background: 'rgba(34,197,94,.16)' }} />
          <span className="relative inline-block rounded-full border border-white/25 bg-white/10 px-3 py-[5px] text-[11px] font-semibold tracking-[1.4px] text-white/85">
            {t.today.toUpperCase()}
          </span>
          <p className="pc-display relative mt-3 text-[24px] font-semibold leading-tight text-white">{t.title}</p>
        </div>

        {/* SchoolLifeShortcuts */}
        <div className="mt-4 grid grid-cols-3 gap-2">
          {[
            { p: mdiCalendarWeek, c: PC.primaryBlue, l: t.timetable },
            { p: mdiPartyPopper, c: PC.heart, l: t.events, b: 2 },
            { p: mdiBus, c: PC.leafGreen, l: t.bus },
          ].map((s) => (
            <Card key={s.l} className="!px-2 !py-3 text-center">
              <span className="relative mx-auto block w-10">
                <IconTile path={s.p} color={s.c} />
                {s.b && (
                  <span className="absolute -right-1.5 -top-1.5 flex h-[18px] min-w-[18px] items-center justify-center rounded-full text-[10px] font-bold text-white" style={{ background: PC.error }}>
                    {s.b}
                  </span>
                )}
              </span>
              <span className="mt-1.5 block truncate text-[13px] font-semibold" style={{ color: PC.charcoal }}>
                {s.l}
              </span>
            </Card>
          ))}
        </div>

        {/* TodayPeriodsCard */}
        <Card className="mt-5">
          <div className="flex items-center justify-between">
            <span className="text-[15px] font-semibold" style={{ color: PC.charcoal }}>
              {t.periods}
            </span>
            <span className="text-[12px]" style={{ color: PC.grey500 }}>
              6 periods
            </span>
          </div>
          <Period tag={t.now} tone={PC.primaryBlue} subject="Science" time="10:30 – 11:10 AM" teacher="Ms. Kavya" icon={mdiFlaskOutline} />
          <Period tag={t.next} tone={PC.grey500} subject="Tamil" time="11:10 – 11:50 AM" teacher="Mr. Senthil" icon={mdiTranslate} muted />
        </Card>

        <div className="mt-6">
          <SectionHeader title={t.hwStatus} action={t.seeAll} />
          <HomeworkCard subject="Mathematics" title="Fractions — worksheet 4" due={<Badge tone="warning">{t.dueToday}</Badge>} icon={mdiCalculatorVariantOutline} color={PC.primaryBlue} />
        </div>
      </div>
    </ConnectScreen>
  )
}

function Period({ tag, tone, subject, time, teacher, icon, muted }: { tag: string; tone: string; subject: string; time: string; teacher: string; icon: string; muted?: boolean }) {
  return (
    <div className="mt-3 flex items-center gap-3" style={{ opacity: muted ? 0.75 : 1 }}>
      <IconTile path={icon} color={tone} size={38} iconSize={20} />
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="text-[15px] font-semibold" style={{ color: PC.charcoal }}>
            {subject}
          </span>
          <span className="rounded-full px-2 py-[1px] text-[10.5px] font-bold" style={{ background: `${tone}1f`, color: tone }}>
            {tag}
          </span>
        </div>
        <span className="text-[12.5px]" style={{ color: PC.grey500 }}>
          {time} · {teacher}
        </span>
      </div>
    </div>
  )
}

export function HomeworkCard({ subject, title, due, icon, color, done }: { subject: string; title: string; due: React.ReactNode; icon: string; color: string; done?: boolean }) {
  return (
    <Card className="flex items-center gap-3">
      <IconTile path={icon} color={color} />
      <div className="min-w-0 flex-1">
        <span className="block text-[12px] font-semibold uppercase tracking-[0.6px]" style={{ color }}>
          {subject}
        </span>
        <span className="block truncate text-[15px] font-semibold" style={{ color: PC.charcoal, textDecoration: done ? 'line-through' : undefined, opacity: done ? 0.6 : 1 }}>
          {title}
        </span>
        <span className="mt-1 block">{due}</span>
      </div>
      <span
        className="flex h-8 w-8 items-center justify-center rounded-full border-2"
        style={{ borderColor: done ? PC.success : PC.grey200, background: done ? PC.success : 'transparent' }}
      >
        {done && <Icon path={mdiCheck} size={18} color="#fff" />}
      </span>
    </Card>
  )
}

export function HomeworkScreen() {
  return (
    <ConnectScreen>
      <AppBar title="Homework" />
      <div className="px-4">
        <Card luminous className="mb-4">
          <div className="flex items-center justify-between">
            <span className="text-[15px] font-semibold" style={{ color: PC.charcoal }}>
              2 of 5 completed
            </span>
            <span className="text-[13px] font-semibold" style={{ color: PC.primaryBlue }}>
              40%
            </span>
          </div>
          <div className="mt-3 h-2 overflow-hidden rounded-full" style={{ background: PC.grey200 }}>
            <div className="h-full w-[40%] rounded-full" style={{ background: 'linear-gradient(90deg,#2F6BFF,#3EC6FF,#22C55E)' }} />
          </div>
        </Card>
        <div className="mb-4 flex gap-2">
          {['All', 'Pending', 'Under Review', 'Completed'].map((f, i) => (
            <span
              key={f}
              className="rounded-full border px-3.5 py-1.5 text-[13px] font-semibold"
              style={i === 0 ? { background: PC.primaryBlue, color: '#fff', borderColor: PC.primaryBlue } : { background: 'rgba(255,255,255,.8)', color: PC.grey600, borderColor: PC.grey200 }}
            >
              {f}
            </span>
          ))}
        </div>
        <div className="flex flex-col gap-3">
          <HomeworkCard subject="Mathematics" title="Fractions — worksheet 4" due={<Badge tone="warning">Due today</Badge>} icon={mdiCalculatorVariantOutline} color={PC.primaryBlue} />
          <HomeworkCard subject="English" title="Five sentences about the monsoon" due={<Badge tone="info">Due tomorrow</Badge>} icon={mdiBookOpenVariant} color="#7C3AED" />
          <HomeworkCard subject="Science" title="Label the parts of a plant" due={<Badge tone="info">Under Review</Badge>} icon={mdiFlaskOutline} color={PC.leafGreen} />
          <HomeworkCard subject="Social Science" title="Map work — rivers of India" due={<Badge tone="success">Completed</Badge>} icon={mdiEarth} color="#0EA5E9" done />
          <HomeworkCard subject="Tamil" title="Read lesson 6 aloud" due={<Badge tone="success">Completed</Badge>} icon={mdiTranslate} color={PC.heart} done />
        </div>
      </div>
    </ConnectScreen>
  )
}

export function DiaryScreen() {
  const group = (title: string, icon: string, color: string, items: { t: string; s: string }[]) => (
    <div className="mt-4">
      <SectionHeader title={title} />
      <div className="flex flex-col gap-2.5">
        {items.map((it) => (
          <Card key={it.t} className="flex gap-3 !py-3.5">
            <IconTile path={icon} color={color} size={38} iconSize={20} />
            <div className="min-w-0">
              <span className="block text-[14.5px] font-semibold leading-snug" style={{ color: PC.charcoal }}>
                {it.t}
              </span>
              <span className="mt-0.5 block text-[12.5px] leading-snug" style={{ color: PC.grey500 }}>
                {it.s}
              </span>
            </div>
          </Card>
        ))}
      </div>
    </div>
  )
  return (
    <ConnectScreen nav="diary">
      <div className="px-4 pt-1">
        <div className="flex items-center justify-between">
          <span className="pc-display text-[24px] font-semibold" style={{ color: PC.charcoal }}>
            Diary
          </span>
          <span className="flex gap-1">
            <span className="flex h-10 w-10 items-center justify-center">
              <Icon path={mdiClipboardTextOutline} size={23} color={PC.primaryBlue} />
            </span>
            <span className="flex h-10 w-10 items-center justify-center">
              <Icon path={mdiCalendarMonthOutline} size={23} color={PC.charcoal} />
            </span>
          </span>
        </div>
        <div className="mt-3 flex h-12 items-center gap-2 rounded-[18px] border bg-white/85 px-3.5" style={{ borderColor: PC.grey200 }}>
          <Icon path={mdiMagnify} size={22} color={PC.grey500} />
          <span className="text-[14.5px]" style={{ color: PC.grey400 }}>
            Science, parent meeting…
          </span>
        </div>
        <div className="mt-3 flex items-center justify-between">
          <Icon path={mdiChevronLeft} size={26} color={PC.charcoal} />
          <span className="text-[15px] font-semibold" style={{ color: PC.charcoal }}>
            {DATE.short}
          </span>
          <Icon path={mdiChevronRight} size={26} color={PC.charcoal} />
        </div>
        {group('Homework', mdiBookOpenVariant, PC.primaryBlue, [
          { t: 'Mathematics — Fractions worksheet 4', s: 'Complete questions 1–12 · Due today' },
        ])}
        {group('Teacher notes', mdiNoteTextOutline, PC.leafGreen, [{ t: 'Aadhya led her group well in today’s science activity.', s: `By ${STUDENT.teacher}` }])}
        {group('School notices', mdiBullhornOutline, PC.warning, [{ t: 'Parent meeting on Saturday, 10:00 AM', s: 'Classes 1–5 · Main hall' }])}
        {group('Activities', mdiTrophyOutline, PC.heart, [{ t: 'Inter-house quiz — 2nd place', s: 'Blue house · Quiz club' }])}
      </div>
    </ConnectScreen>
  )
}
