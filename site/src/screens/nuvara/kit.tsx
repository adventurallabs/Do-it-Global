import type { CSSProperties, ReactNode } from 'react'
import {
  mdiBattery,
  mdiCalendarMonth,
  mdiCalendarMonthOutline,
  mdiCalendarToday,
  mdiCalendarTodayOutline,
  mdiCalendarWeek,
  mdiCalendarWeekOutline,
  mdiChartTimelineVariantShimmer,
  mdiChat,
  mdiChatOutline,
  mdiFormatQuoteOpen,
  mdiHome,
  mdiHomeOutline,
  mdiSignalCellular3,
  mdiTrendingNeutral,
  mdiTrendingUp,
  mdiWallet,
  mdiWalletOutline,
  mdiWifi,
  mdiBabyFace,
  mdiBabyFaceOutline,
  mdiArrowLeft,
  mdiClose,
  mdiCloudOffOutline,
  mdiCloudCheckOutline,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'
import { MARK_DOTS, MARK_U } from './mark'

/**
 * Nuvara's design system, recreated from lib/theme.dart and lib/widgets/ui.dart:
 * the navy / orange / sky palette taken from the logo, Archivo headings with
 * Plus Jakarta Sans body text, white cards with navy-tinted shadows, the navy
 * hero surface, and the role shells from lib/widgets/shell.dart (a bottom
 * NavigationBar on phones, a NavigationRail from 840px).
 */
export const NV = {
  canvas: '#F5F6FB',
  ink: '#0D0E2C',
  muted: '#62667F',
  line: '#E5E7F1',
  sand: '#EDEFF6',
  brand50: '#EFF0FA',
  brand100: '#DDE0F5',
  brand200: '#BAC0EA',
  brand300: '#8F98D8',
  brand400: '#5E68BE',
  brand600: '#262C82',
  brand700: '#161A66',
  brand800: '#0B0E50',
  brand900: '#010039',
  clay50: '#FFF2EC',
  clay100: '#FFDFD0',
  clay500: '#EA501E',
  clay600: '#C93F12',
  sky: '#36A9E0',
  skyBg: '#E6F5FC',
  green: '#107443',
  greenBg: '#E6F6EE',
  amber: '#A35A00',
  amberBg: '#FFF4E0',
  red: '#C0263D',
  redBg: '#FDECEF',
  blue: '#1772B5',
  blueBg: '#E7F3FC',
  violet: '#6B3FA0',
  violetBg: '#F2ECFA',
}

/** Layered, navy-tinted shadow (softShadow in ui.dart). */
export const softShadow = '0 1px 2px rgba(1,0,57,.04), 0 12px 26px -12px rgba(1,0,57,.08)'
export const heroGradient = `linear-gradient(135deg, ${NV.brand900}, #1B1F7A)`

/* ------------------------------------------------------------------ */
/*  Type: display() is Archivo with light weights lifted; body() is      */
/*  Plus Jakarta Sans. Both exactly as sized in the app.                 */
/* ------------------------------------------------------------------ */
export function d(size: number, weight = 500, color: string = NV.ink, height?: number): CSSProperties {
  const w = weight <= 400 ? 600 : weight <= 500 ? 700 : 800
  return { fontFamily: "'Archivo Variable', 'Archivo', sans-serif", fontSize: size, fontWeight: w, color, lineHeight: height ?? 1.15, letterSpacing: size >= 24 ? -0.6 : -0.2 }
}
export function b(size: number, weight = 400, color: string = NV.ink, height?: number): CSSProperties {
  return { fontSize: size, fontWeight: weight, color, lineHeight: height }
}
export const tnum: CSSProperties = { fontVariantNumeric: 'tabular-nums' }

/* ------------------------------------------------------------------ */
/*  Brand                                                               */
/* ------------------------------------------------------------------ */
export function NuvaraMark({ size = 40, mono }: { size?: number; mono?: string }) {
  return (
    <svg viewBox="0 -0.01 0.9 1.02" width={size * 0.9} height={size} aria-hidden className="shrink-0">
      <path d={MARK_U} fill={mono ?? NV.clay500} />
      {MARK_DOTS.map(([x, y, r]) => (
        <circle key={x} cx={x} cy={y} r={r} fill={mono ?? NV.sky} />
      ))}
    </svg>
  )
}

/** The app tile: the mark on navy, as on the launcher icon (Logo in shell.dart). */
export function Logo({ size = 40 }: { size?: number }) {
  return (
    <span className="flex shrink-0 items-center justify-center" style={{ width: size, height: size, borderRadius: size * 0.3, background: NV.brand900, boxShadow: '0 4px 10px rgba(1,0,57,.25)' }}>
      <NuvaraMark size={size * 0.62} />
    </span>
  )
}

/** "nüvara." on one line, as in the logo. */
export function Wordmark({ height = 16, light }: { height?: number; light?: boolean }) {
  const ink = light ? '#fff' : NV.brand900
  const st: CSSProperties = { fontFamily: "'Archivo Variable', sans-serif", fontSize: height * 1.38, fontWeight: 900, color: ink, lineHeight: 1, letterSpacing: -height * 0.06 }
  return (
    <span className="inline-flex items-end" aria-label="Nuvara">
      <span style={st}>n</span>
      <span style={{ margin: `0 ${height * 0.02}px ${height * 0.16}px` }}>
        <NuvaraMark size={height * 1.42} />
      </span>
      <span style={st}>vara</span>
      <span className="rounded-full" style={{ width: height * 0.26, height: height * 0.26, background: NV.sky, marginLeft: height * 0.06, marginBottom: height * 0.12 }} />
    </span>
  )
}

/* ------------------------------------------------------------------ */
/*  Shell                                                                */
/* ------------------------------------------------------------------ */
export type Role = 'parent' | 'therapist' | 'admin'
type Tab = { id: string; label: string; icon: string; active: string; badge?: number; tone?: 'amber' }

const TABS: Record<Role, Tab[]> = {
  admin: [
    { id: 'home', label: 'Home', icon: mdiHomeOutline, active: mdiHome },
    { id: 'timetable', label: 'Timetable', icon: mdiCalendarWeekOutline, active: mdiCalendarWeek },
    { id: 'children', label: 'Children', icon: mdiBabyFaceOutline, active: mdiBabyFace },
    { id: 'fees', label: 'Fees', icon: mdiWalletOutline, active: mdiWallet },
    { id: 'messages', label: 'Messages', icon: mdiChatOutline, active: mdiChat, badge: 2 },
  ],
  therapist: [
    { id: 'today', label: 'Today', icon: mdiCalendarTodayOutline, active: mdiCalendarToday },
    { id: 'week', label: 'Week', icon: mdiCalendarWeekOutline, active: mdiCalendarWeek },
    { id: 'children', label: 'Children', icon: mdiBabyFaceOutline, active: mdiBabyFace },
    { id: 'messages', label: 'Messages', icon: mdiChatOutline, active: mdiChat },
  ],
  parent: [
    { id: 'home', label: 'Home', icon: mdiHomeOutline, active: mdiHome },
    { id: 'schedule', label: 'Schedule', icon: mdiCalendarMonthOutline, active: mdiCalendarMonth, badge: 1, tone: 'amber' },
    { id: 'progress', label: 'Progress', icon: mdiChartTimelineVariantShimmer, active: mdiChartTimelineVariantShimmer },
    { id: 'fees', label: 'Fees', icon: mdiWalletOutline, active: mdiWallet },
    { id: 'messages', label: 'Messages', icon: mdiChatOutline, active: mdiChat, badge: 1 },
  ],
}

type ScreenProps = {
  children: ReactNode
  role: Role
  /** The selected tab; omit for a pushed screen (no navigation bar on phones). */
  tab?: string
  /** A pushed screen's app bar (back arrow + title). */
  bar?: ReactNode
  /** Content keeps to the app's reading width (maxContent = 760) on wide screens. */
  wide?: boolean
  badges?: Partial<Record<string, number>>
  /** How far the page is scrolled, in px (the screens are scroll views). */
  scroll?: number
  /** Drawn over everything (a bottom sheet with its barrier). */
  overlay?: ReactNode
  /** The offline bar from widgets/offline_banner.dart. */
  network?: 'offline' | 'online'
  style?: CSSProperties
}

/**
 * A role shell at real device size. Below 700px of screen (a phone) it has a
 * status bar and the bottom NavigationBar; wider (a tablet) it has the
 * NavigationRail with the Nuvara tile, like the app from 840 logical px.
 */
export function NuvaraScreen({ children, role, tab, bar, wide, badges, scroll = 0, overlay, network, style }: ScreenProps) {
  const tabs = TABS[role].map((t) => ({ ...t, badge: badges && t.id in badges ? badges[t.id] : t.badge }))
  return (
    <div className="nv absolute inset-0 overflow-hidden" style={{ background: NV.canvas, ...style }}>
      <StatusBar />
      <div className="absolute inset-x-0 bottom-0 top-[50px] flex @[700px]:top-[30px]">
        {tab && <Rail tabs={tabs} active={tab} />}
        <div className="relative min-w-0 flex-1">
          {bar}
          {network && <NetworkBar state={network} />}
          <div className="absolute inset-x-0 bottom-0 overflow-hidden" style={{ top: (bar ? 56 : 0) + (network ? 46 : 0) }}>
            <div
              className={`px-4 pb-28 pt-2 transition-transform duration-700 ease-[cubic-bezier(.16,1,.3,1)] @[700px]:px-8 @[700px]:pb-8 ${wide === false ? '' : '@[700px]:mx-auto @[700px]:max-w-[792px]'}`}
              style={scroll ? { transform: `translateY(${-scroll}px)` } : undefined}
            >
              {children}
            </div>
          </div>
        </div>
      </div>
      {tab && <BottomBar tabs={tabs} active={tab} />}
      {overlay}
    </div>
  )
}

function NetworkBar({ state }: { state: 'offline' | 'online' }) {
  const off = state === 'offline'
  const fg = off ? NV.amber : NV.green
  return (
    <div className="absolute inset-x-0 top-0 z-20 flex h-[46px] items-center gap-2.5 pl-4 pr-2" style={{ background: off ? NV.amberBg : NV.greenBg }}>
      <Icon path={off ? mdiCloudOffOutline : mdiCloudCheckOutline} size={18} color={fg} />
      <span className="min-w-0 flex-1 truncate" style={b(12.5, 700, fg, 1.3)}>
        {off ? 'You’re offline · showing data from 9:12 AM' : 'Back online'}
      </span>
      {off && <span className="px-2.5" style={b(14, 600, fg)}>Retry</span>}
    </div>
  )
}

export function StatusBar() {
  return (
    <div className="absolute inset-x-0 top-0 z-40 flex h-[50px] items-center justify-between px-8 pt-1 text-[15px] font-semibold @[700px]:h-[30px] @[700px]:px-6 @[700px]:pt-0 @[700px]:text-[13px]" style={{ color: NV.ink }}>
      <span style={{ fontFamily: 'system-ui, sans-serif' }}>9:41</span>
      <span className="flex items-center gap-1">
        <Icon path={mdiSignalCellular3} size={16} color={NV.ink} />
        <Icon path={mdiWifi} size={16} color={NV.ink} />
        <Icon path={mdiBattery} size={19} color={NV.ink} className="rotate-90" />
      </span>
    </div>
  )
}

/** Material 3 NavigationBar themed in theme.dart: white, clay50 indicator, orange icon, navy label. */
function BottomBar({ tabs, active }: { tabs: Tab[]; active: string }) {
  return (
    <div
      className="absolute inset-x-0 bottom-0 z-30 flex h-[92px] items-start justify-around px-1 pt-[11px] @[700px]:hidden"
      style={{ background: '#fff', borderTop: `1px solid ${NV.line}`, boxShadow: '0 -4px 18px rgba(1,0,57,.06)' }}
    >
      {tabs.map((t) => {
        const on = t.id === active
        return (
          <div key={t.id} className="flex min-w-0 flex-1 flex-col items-center gap-[5px]">
            <span className="relative flex h-8 w-16 items-center justify-center rounded-full" style={{ background: on ? NV.clay50 : 'transparent' }}>
              <Icon path={on ? t.active : t.icon} size={22} color={on ? NV.clay500 : NV.muted} />
              <NavBadge n={t.badge} tone={t.tone} />
            </span>
            <span className="max-w-full truncate" style={b(11.5, on ? 800 : 600, on ? NV.brand900 : NV.muted)}>
              {t.label}
            </span>
          </div>
        )
      })}
    </div>
  )
}

function Rail({ tabs, active }: { tabs: Tab[]; active: string }) {
  return (
    <div className="hidden w-[92px] shrink-0 flex-col items-center gap-3 pt-3 @[700px]:flex" style={{ background: '#fff', borderRight: `1px solid ${NV.line}` }}>
      <div className="mb-4">
        <Logo size={36} />
      </div>
      {tabs.map((t) => {
        const on = t.id === active
        return (
          <div key={t.id} className="flex flex-col items-center gap-1">
            <span className="relative flex h-8 w-14 items-center justify-center rounded-full" style={{ background: on ? NV.brand100 : 'transparent' }}>
              <Icon path={on ? t.active : t.icon} size={22} color={on ? NV.brand800 : NV.muted} />
              <NavBadge n={t.badge} tone={t.tone} />
            </span>
            <span style={b(13, on ? 700 : 600, on ? NV.brand800 : NV.muted)}>{t.label}</span>
          </div>
        )
      })}
    </div>
  )
}

function NavBadge({ n, tone }: { n?: number; tone?: 'amber' }) {
  if (!n) return null
  return (
    <span className="absolute left-[34px] top-[-3px] flex h-4 min-w-4 items-center justify-center rounded-full px-1 text-[10.5px] font-bold text-white" style={{ background: tone === 'amber' ? NV.amber : NV.clay600 }}>
      {n}
    </span>
  )
}

/** A pushed screen's AppBar: canvas background, back arrow, 15px w600 title. */
export function AppBar({ title, trailing }: { title: ReactNode; trailing?: ReactNode }) {
  return (
    <div className="absolute inset-x-0 top-0 z-20 flex h-14 items-center gap-2 px-2" style={{ background: NV.canvas }}>
      <span className="flex h-10 w-10 items-center justify-center">
        <Icon path={mdiArrowLeft} size={22} color={NV.ink} />
      </span>
      <span className="min-w-0 flex-1 truncate" style={b(15, 600)}>
        {title}
      </span>
      {trailing}
    </div>
  )
}

/* ------------------------------------------------------------------ */
/*  Surfaces                                                            */
/* ------------------------------------------------------------------ */
export function Card({ children, className = '', style, pad = 16, radius = 20, border = NV.line, color = '#fff' }: { children: ReactNode; className?: string; style?: CSSProperties; pad?: number; radius?: number; border?: string; color?: string }) {
  return (
    <div className={className} style={{ background: color, border: `1px solid ${border}`, borderRadius: radius, boxShadow: softShadow, padding: pad, ...style }}>
      {children}
    </div>
  )
}

/** The navy hero surface: deep gradient, soft sky and orange light, a fine top highlight. */
export function Hero({ children, pad = 20, radius = 26, className = '' }: { children: ReactNode; pad?: number | string; radius?: number; className?: string }) {
  return (
    <div className={`relative overflow-hidden ${className}`} style={{ borderRadius: radius, background: heroGradient, boxShadow: '0 14px 28px -16px rgba(1,0,57,.18)' }}>
      <span className="pointer-events-none absolute -right-[70px] -top-[90px] h-[220px] w-[220px] rounded-full" style={{ background: 'radial-gradient(circle, rgba(54,169,224,.30), rgba(54,169,224,0) 70%)' }} />
      <span className="pointer-events-none absolute -bottom-[110px] -left-[60px] h-[220px] w-[220px] rounded-full" style={{ background: 'radial-gradient(circle, rgba(234,80,30,.26), rgba(234,80,30,0) 70%)' }} />
      <span className="pointer-events-none absolute inset-x-0 top-0 h-px" style={{ background: 'linear-gradient(90deg, rgba(255,255,255,0), rgba(255,255,255,.22), rgba(255,255,255,0))' }} />
      <div className="relative" style={{ padding: pad }}>
        {children}
      </div>
    </div>
  )
}

export function HeroOverline({ children }: { children: ReactNode }) {
  return (
    <span className="block truncate uppercase" style={{ ...b(11, 800, NV.brand200), letterSpacing: 1.1 }}>
      {children}
    </span>
  )
}

export function HeroPill({ children, dot = NV.brand300 }: { children: ReactNode; dot?: string }) {
  return (
    <span className="inline-flex max-w-full items-center gap-1.5 rounded-full px-2.5 py-[5px]" style={{ background: 'rgba(255,255,255,.1)' }}>
      <span className="h-[7px] w-[7px] shrink-0 rounded-full" style={{ background: dot }} />
      <span className="truncate" style={b(11, 700, '#fff', 1.1)}>
        {children}
      </span>
    </span>
  )
}
export const heroDot = { green: '#6EE7B7', amber: '#FCD34D', red: '#FCA5A5', violet: '#C4B5FD', blue: '#93C5FD' }

export function HeroStat({ v, l }: { v: string; l: string }) {
  return (
    <div className="flex min-w-0 flex-1 flex-col items-center">
      <span style={{ ...d(24, 500, '#fff'), ...tnum }}>{v}</span>
      <span className="mt-0.5 truncate" style={b(11, 600, NV.brand200)}>
        {l}
      </span>
    </div>
  )
}
export const HeroDivider = () => <span className="h-[30px] w-px shrink-0" style={{ background: 'rgba(255,255,255,.12)' }} />

/* ------------------------------------------------------------------ */
/*  Pieces                                                               */
/* ------------------------------------------------------------------ */
export type Tone = 'green' | 'amber' | 'red' | 'blue' | 'violet' | 'neutral'
export const toneColors: Record<Tone, { fg: string; bg: string }> = {
  green: { fg: NV.green, bg: NV.greenBg },
  amber: { fg: NV.amber, bg: NV.amberBg },
  red: { fg: NV.red, bg: NV.redBg },
  blue: { fg: NV.blue, bg: NV.blueBg },
  violet: { fg: NV.violet, bg: NV.violetBg },
  neutral: { fg: '#545872', bg: '#EEF0F6' },
}

export function Chip({ children, tone = 'neutral', dot = true }: { children: ReactNode; tone?: Tone; dot?: boolean }) {
  const c = toneColors[tone]
  return (
    <span className="inline-flex max-w-full shrink-0 items-center gap-1.5 rounded-full px-[9px] py-[5px]" style={{ background: c.bg }}>
      {dot && <span className="h-1.5 w-1.5 shrink-0 rounded-full" style={{ background: c.fg }} />}
      <span className="truncate" style={b(11, 700, c.fg, 1.1)}>
        {children}
      </span>
    </span>
  )
}

export function IdBadge({ code, light }: { code: string; light?: boolean }) {
  return (
    <span className="inline-block shrink-0 rounded-md px-1.5 py-[2.5px]" style={{ background: light ? 'rgba(255,255,255,.14)' : NV.sand, ...b(10.5, 700, light ? '#fff' : 'rgba(13,14,44,.72)', 1.2), letterSpacing: 0.3, ...tnum }}>
      {code}
    </span>
  )
}

const AVATARS = ['#161A66', '#D9481A', '#1F8CC4', '#6A3FA0', '#0E7C6B', '#B0306A', '#3B4FB8', '#B86A0E']
/** avatarColor(): the same name always gets the same colour. */
export function avatarColor(name: string) {
  let a = 0
  for (const ch of name) a = (a * 31 + ch.charCodeAt(0)) & 0x7fffffff
  return AVATARS[a % AVATARS.length]
}
const lighten = (hex: string, t: number) => {
  const n = parseInt(hex.slice(1), 16)
  const c = [n >> 16, (n >> 8) & 255, n & 255].map((v) => Math.round(v + (255 - v) * t))
  return `rgb(${c.join(',')})`
}
export const initials = (name: string) =>
  name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0])
    .join('')
    .toUpperCase()

export function Avatar({ name, size = 40, ring }: { name: string; size?: number; ring?: boolean }) {
  const c = avatarColor(name)
  return (
    <span
      className="flex shrink-0 items-center justify-center rounded-full text-white"
      style={{ width: size, height: size, background: `linear-gradient(135deg, ${lighten(c, 0.14)}, ${c})`, border: ring ? '2px solid #fff' : undefined, ...b(size * 0.36, 700, '#fff', 1) }}
    >
      {initials(name)}
    </span>
  )
}

export function AvatarStack({ names, size = 26, max = 4 }: { names: string[]; size?: number; max?: number }) {
  const shown = names.slice(0, max)
  const extra = names.length - shown.length
  return (
    <span className="flex">
      {shown.map((n, i) => (
        <span key={n + i} style={{ marginLeft: i ? -size * 0.32 : 0 }}>
          <Avatar name={n} size={size} ring />
        </span>
      ))}
      {extra > 0 && (
        <span className="flex items-center justify-center rounded-full" style={{ marginLeft: -size * 0.32, width: size, height: size, background: NV.sand, border: '2px solid #fff', ...b(size * 0.36, 700, NV.muted, 1) }}>
          +{extra}
        </span>
      )}
    </span>
  )
}

export function IconTile({ path, color = NV.brand700, size = 42 }: { path: string; color?: string; size?: number }) {
  return (
    <span className="flex shrink-0 items-center justify-center" style={{ width: size, height: size, borderRadius: size * 0.3, background: `${color}1a` }}>
      <Icon path={path} size={size * 0.48} color={color} />
    </span>
  )
}

export function SectionTitle({ title, hint, action }: { title: string; hint?: string; action?: string }) {
  return (
    <div className="mb-3 flex items-end gap-2">
      <div className="min-w-0 flex-1">
        <span className="block" style={d(19)}>
          {title}
        </span>
        {hint && (
          <span className="mt-0.5 block truncate" style={b(12.5, 400, NV.muted)}>
            {hint}
          </span>
        )}
      </div>
      {action && <span style={b(14, 600, NV.brand700)}>{action}</span>}
    </div>
  )
}

export function TabHeader({ title, sub, trailing }: { title: string; sub?: string; trailing?: ReactNode }) {
  return (
    <div className="flex items-end pb-[18px] pt-2.5">
      <div className="min-w-0 flex-1">
        <span className="block" style={d(30, 500)}>
          {title}
        </span>
        {sub && (
          <span className="mt-1 block" style={b(13.5, 400, NV.muted)}>
            {sub}
          </span>
        )}
      </div>
      {trailing}
    </div>
  )
}

/** "Good morning," over a big first name, with the account avatar. */
export function Greeting({ name, avatar }: { name: string; avatar: string }) {
  return (
    <div className="flex items-center gap-3 pb-[18px] pt-2.5">
      <div className="min-w-0 flex-1">
        <span className="block" style={b(14, 600, NV.muted)}>
          Good morning,
        </span>
        <span className="block truncate" style={d(30)}>
          {name}
        </span>
      </div>
      <Avatar name={avatar} size={46} />
    </div>
  )
}

export function RatingPill({ r, large }: { r: number; large?: boolean }) {
  const c = r >= 7 ? NV.green : r >= 4 ? NV.amber : NV.red
  return (
    <span className="inline-flex shrink-0 items-baseline rounded-full" style={{ background: `${c}1a`, padding: large ? '5px 10px' : '3px 8px', ...tnum }}>
      <span style={b(large ? 15 : 12.5, 800, c)}>{r}</span>
      <span style={b(large ? 11.5 : 10.5, 700, `${c}b3`)}>/10</span>
    </span>
  )
}

export function TrendBadge({ change }: { change: number }) {
  const flat = Math.abs(change) < 0.25
  const fg = flat ? NV.muted : change > 0 ? NV.green : NV.amber
  return (
    <span className="inline-flex items-center gap-1 rounded-full px-2 py-[3px]" style={{ background: flat ? NV.sand : change > 0 ? NV.greenBg : NV.amberBg }}>
      <Icon path={flat ? mdiTrendingNeutral : mdiTrendingUp} size={14} color={fg} />
      <span style={b(11, 700, fg)}>{flat ? 'Steady' : `+${change.toFixed(1)} lately`}</span>
    </span>
  )
}

export function Bar({ value, color = NV.clay500, h = 8 }: { value: number; color?: string; h?: number }) {
  return (
    <span className="block w-full overflow-hidden rounded-full" style={{ height: h, background: NV.sand }}>
      <span className="block h-full rounded-full transition-[width] duration-500" style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%`, background: color }} />
    </span>
  )
}

/** A therapist's note, set apart as a soft quote. */
export function NoteQuote({ children, lines }: { children: ReactNode; lines?: number }) {
  return (
    <div className="flex gap-2 rounded-[14px] px-3 pb-[11px] pt-2.5" style={{ background: NV.brand50 }}>
      <Icon path={mdiFormatQuoteOpen} size={18} color={NV.brand400} className="mt-px shrink-0" />
      <span style={{ ...b(13.5, 400, NV.ink, 1.45), ...(lines ? { display: '-webkit-box', WebkitLineClamp: lines, WebkitBoxOrient: 'vertical', overflow: 'hidden' } : {}) }}>{children}</span>
    </div>
  )
}

/** The app's toggle: a sand track with one raised, white segment. */
export function Segmented({ options, value, expand }: { options: { label: string; icon?: string }[]; value: number; expand?: boolean }) {
  return (
    <div className={`${expand ? 'flex' : 'inline-flex'} rounded-[13px] p-1`} style={{ background: NV.sand }}>
      {options.map((o, i) => {
        const on = i === value
        return (
          <span key={o.label} className={`flex h-11 items-center justify-center gap-1.5 rounded-[10px] px-3 ${expand ? 'flex-1' : ''}`} style={{ background: on ? '#fff' : 'transparent', boxShadow: on ? '0 2px 6px rgba(1,0,57,.11)' : undefined }}>
            {o.icon && <Icon path={o.icon} size={15} color={on ? NV.brand800 : NV.muted} />}
            <span style={b(12.5, 600, on ? NV.brand800 : NV.muted)}>{o.label}</span>
          </span>
        )
      })}
    </div>
  )
}

type BtnKind = 'filled' | 'outlined' | 'soft' | 'white' | 'ghostDark' | 'accent' | 'text'
export function Btn({ children, kind = 'filled', icon, className = '', h = 46, style }: { children: ReactNode; kind?: BtnKind; icon?: string; className?: string; h?: number; style?: CSSProperties }) {
  const look: Record<BtnKind, CSSProperties> = {
    filled: { background: NV.brand800, color: '#fff' },
    outlined: { background: '#fff', color: NV.ink, border: `1px solid ${NV.line}` },
    soft: { background: NV.brand50, color: NV.brand800 },
    white: { background: '#fff', color: NV.brand900 },
    ghostDark: { background: 'rgba(255,255,255,.12)', color: '#fff', border: '1px solid rgba(255,255,255,.4)' },
    accent: { background: NV.clay600, color: '#fff' },
    text: { background: 'transparent', color: NV.brand700 },
  }
  return (
    <span className={`flex min-w-0 items-center justify-center gap-2 rounded-[14px] px-4 ${className}`} style={{ height: h, ...b(14, 600), ...look[kind], ...style }}>
      {icon && <Icon path={icon} size={18} color="currentColor" />}
      <span className="truncate">{children}</span>
    </span>
  )
}

export const Divider = ({ indent = 0 }: { indent?: number }) => <div style={{ height: 1, background: NV.line, marginLeft: indent }} />

/** showSheet() on a phone: navy-tinted barrier, white sheet, drag handle, title row, divider. */
export function Sheet({ title, sub, children, footer }: { title: string; sub?: string; children: ReactNode; footer?: ReactNode }) {
  return (
    <div className="absolute inset-0 z-50 flex flex-col justify-end" style={{ background: 'rgba(1,0,57,.45)' }}>
      <div className="overflow-hidden rounded-t-[28px] bg-white pb-6">
        <div className="mx-auto mt-2.5 h-1 w-[38px] rounded-full" style={{ background: NV.line }} />
        <div className="flex items-start gap-2 pb-2.5 pl-5 pr-3 pt-3.5">
          <div className="min-w-0 flex-1">
            <span className="block" style={d(22)}>
              {title}
            </span>
            {sub && (
              <span className="mt-[3px] block" style={b(13.5, 400, NV.muted)}>
                {sub}
              </span>
            )}
          </div>
          <span className="flex h-10 w-10 items-center justify-center">
            <Icon path={mdiClose} size={22} color={NV.muted} />
          </span>
        </div>
        <Divider />
        <div className="px-5 pb-5 pt-4">{children}</div>
        {footer && (
          <>
            <Divider />
            <div className="flex gap-2.5 px-5 pt-3">{footer}</div>
          </>
        )}
      </div>
    </div>
  )
}
