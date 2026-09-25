import {
  mdiAccountOutline,
  mdiBookOpenVariant,
  mdiBus,
  mdiCalendarCheckOutline,
  mdiCalendarWeek,
  mdiChatOutline,
  mdiClipboardTextOutline,
  mdiCurrencyInr,
  mdiFlaskOutline,
  mdiPartyPopper,
  mdiSchoolOutline,
  mdiStarOutline,
  mdiWhiteBalanceSunny,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { STUDENT } from '../../data/sample'
import type { SchoolBrand } from '../../data/brands'
import { Avatar, Bell, Card, PC, StatusBar } from './kit'

/** A school crest drawn from the school's colour and initials. */
export function Crest({ brand, size = 40 }: { brand: SchoolBrand; size?: number }) {
  const { color, deep, soft, initials, crest } = brand
  const text = (
    <text x="32" y={crest === 'star' ? 40 : 38} textAnchor="middle" fontFamily="Georgia, serif" fontWeight="700" fontSize={initials.length > 2 ? 15 : 18} fill="#fff">
      {initials}
    </text>
  )
  return (
    <svg viewBox="0 0 64 64" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id={`crest-${brand.short}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={color} />
          <stop offset="1" stopColor={deep} />
        </linearGradient>
      </defs>
      {crest === 'shield' && <path d="M32 4 L56 12 V30 C56 45 45 55 32 60 C19 55 8 45 8 30 V12 Z" fill={`url(#crest-${brand.short})`} stroke={soft} strokeWidth="2.5" />}
      {crest === 'circle' && (
        <>
          <circle cx="32" cy="32" r="27" fill={`url(#crest-${brand.short})`} stroke={soft} strokeWidth="2.5" />
          <circle cx="32" cy="32" r="21" fill="none" stroke="#fff" strokeOpacity=".35" strokeWidth="1.2" />
        </>
      )}
      {crest === 'star' && (
        <>
          <circle cx="32" cy="32" r="27" fill={`url(#crest-${brand.short})`} />
          <path d="M32 9 l3 7 l7-3 l-3 7 l7 3 l-7 3 l3 7 l-7-3 l-3 7 l-3-7 l-7 3 l3-7 l-7-3 l7-3 l-3-7 l7 3 Z" fill={soft} fillOpacity=".35" />
        </>
      )}
      {text}
    </svg>
  )
}

/** The app's launcher icon for a school, as it sits on a parent's phone. */
export function AppIcon({ brand, size = 64 }: { brand: SchoolBrand; size?: number }) {
  return (
    <span
      className="flex items-center justify-center"
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.24,
        background: `linear-gradient(145deg, #ffffff, ${brand.soft}55)`,
        boxShadow: `0 10px 24px -10px ${brand.deep}aa, inset 0 0 0 1px rgba(255,255,255,.6)`,
      }}
    >
      <Crest brand={brand} size={size * 0.74} />
    </span>
  )
}

const TILES = [
  { key: 'homework', p: mdiClipboardTextOutline, l: 'Homework' },
  { key: 'diary', p: mdiBookOpenVariant, l: 'Diary' },
  { key: 'attendance', p: mdiCalendarCheckOutline, l: 'Attendance' },
  { key: 'marks', p: mdiSchoolOutline, l: 'Results' },
  { key: 'timetable', p: mdiCalendarWeek, l: 'Timetable' },
  { key: 'events', p: mdiPartyPopper, l: 'Events' },
  { key: 'stars', p: mdiStarOutline, l: 'Stars' },
  { key: 'fees', p: mdiCurrencyInr, l: 'Fees' },
  { key: 'bus_tracking', p: mdiBus, l: 'School bus' },
]

/**
 * PalliConnect's Today screen dressed in one school's identity: its crest
 * and name in the header, its colour through the hero card, shortcuts and
 * navigation — and only the shortcuts for features the school has on.
 */
export function BrandTodayScreen({ brand, enabled, custom }: { brand: SchoolBrand; enabled?: Set<string>; custom?: boolean }) {
  const on = (k: string) => !enabled || enabled.has(k)
  const tiles = TILES.filter((t) => on(t.key))
  return (
    <div className="pc absolute inset-0 overflow-hidden" style={{ background: `linear-gradient(160deg, #ffffff, ${brand.soft}33 60%, #f8fafc)` }}>
      <div className="pointer-events-none absolute -right-24 -top-24 h-[300px] w-[300px] rounded-full" style={{ background: `radial-gradient(circle, ${brand.color}2a, transparent 70%)` }} />
      <StatusBar />
      <div className="absolute inset-x-0 bottom-0 top-[54px] px-4">
        {/* School header: the school's own crest and name */}
        <div className="flex items-center gap-3 pt-1">
          <Crest brand={brand} size={44} />
          <span className="min-w-0 flex-1">
            <span className="pc-display block truncate text-[18px] font-semibold leading-tight" style={{ color: brand.deep }}>
              {brand.name}
            </span>
            <span className="block text-[12px] font-medium" style={{ color: PC.grey500 }}>
              Parent app
            </span>
          </span>
          <Bell count={2} />
        </div>

        <div className="mt-4 flex items-center gap-2.5">
          <Avatar initials={STUDENT.initials} size={32} />
          <span className="text-[14px] font-semibold" style={{ color: PC.charcoal }}>
            Good morning
          </span>
          <span className="rounded-full px-2 py-0.5 text-[11.5px] font-medium text-white" style={{ background: brand.color }}>
            {STUDENT.className}-{STUDENT.section}
          </span>
        </div>

        <div className="relative mt-3 overflow-hidden rounded-[28px] p-5" style={{ background: `linear-gradient(135deg, ${brand.deep}, ${brand.color})`, boxShadow: `0 16px 36px -12px ${brand.color}88` }}>
          <span className="absolute -right-5 -top-6 h-[110px] w-[110px] rounded-full" style={{ background: `${brand.soft}33` }} />
          <span className="relative inline-block rounded-full border border-white/25 bg-white/10 px-3 py-[4px] text-[10.5px] font-semibold tracking-[1.4px] text-white/85">TODAY AT SCHOOL</span>
          <p className="pc-display relative mt-2.5 text-[22px] font-semibold leading-tight text-white">{STUDENT.first}&apos;s School Day</p>
          <p className="relative mt-1 text-[12.5px] text-white/75">Science now · Tamil next</p>
        </div>

        <div className="mt-4 grid grid-cols-3 gap-2">
          {tiles.slice(0, 9).map((t) => (
            <Card key={t.key} className="!rounded-[18px] !px-1.5 !py-2.5 text-center">
              <span className="mx-auto flex h-9 w-9 items-center justify-center rounded-[11px]" style={{ background: `${brand.color}1f` }}>
                <Icon path={t.p} size={20} color={brand.color} />
              </span>
              <span className="mt-1 block truncate text-[12px] font-semibold" style={{ color: PC.charcoal }}>
                {t.l}
              </span>
            </Card>
          ))}
          {custom && (
            <div className="rounded-[18px] border-2 border-dashed px-1.5 py-2.5 text-center" style={{ borderColor: `${brand.color}66`, background: `${brand.color}0d` }}>
              <span className="mx-auto flex h-9 w-9 items-center justify-center rounded-[11px] text-[20px] font-semibold" style={{ background: brand.color, color: '#fff' }}>
                +
              </span>
              <span className="mt-1 block truncate text-[12px] font-semibold" style={{ color: brand.deep }}>
                Your feature
              </span>
            </div>
          )}
        </div>

        <Card className="mt-3 !py-3">
          <div className="flex items-center gap-3">
            <span className="flex h-9 w-9 items-center justify-center rounded-[11px]" style={{ background: `${brand.color}1f` }}>
              <Icon path={mdiFlaskOutline} size={20} color={brand.color} />
            </span>
            <span className="flex-1">
              <span className="block text-[14px] font-semibold" style={{ color: PC.charcoal }}>
                Science
              </span>
              <span className="block text-[12px]" style={{ color: PC.grey500 }}>
                10:30 – 11:10 AM · Ms. Kavya
              </span>
            </span>
            <span className="rounded-full px-2 py-0.5 text-[11px] font-semibold text-white" style={{ background: brand.color }}>
              Now
            </span>
          </div>
        </Card>
      </div>

      {/* Navigation in the school's colour */}
      <div className="absolute inset-x-4 bottom-3 z-30 flex h-[66px] items-center justify-around rounded-[30px] border bg-white/95" style={{ borderColor: `${brand.color}40`, boxShadow: '0 12px 30px -12px rgba(16,32,55,.25)' }}>
        {[
          { p: mdiWhiteBalanceSunny, l: 'Today', a: true },
          { p: mdiBookOpenVariant, l: 'Diary', hide: !on('diary') },
          { p: mdiChatOutline, l: 'Messages' },
          { p: mdiAccountOutline, l: 'Profile' },
        ]
          .filter((n) => !n.hide)
          .map((n) => (
            <span key={n.l} className="flex w-[64px] flex-col items-center gap-1">
              <span className="flex h-[34px] items-center justify-center rounded-[12px] px-2" style={n.a ? { background: `${brand.color}22` } : undefined}>
                <Icon path={n.p} size={22} color={n.a ? brand.color : PC.grey500} />
              </span>
              <span className="text-[11px] font-medium leading-none" style={{ color: n.a ? brand.color : PC.grey600 }}>
                {n.l}
              </span>
            </span>
          ))}
      </div>
    </div>
  )
}
