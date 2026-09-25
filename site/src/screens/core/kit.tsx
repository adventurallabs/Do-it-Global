import type { CSSProperties, ReactNode } from 'react'
import { mdiBattery, mdiBellOutline, mdiLogout, mdiSignalCellular3, mdiWifi, mdiHome, mdiGoogleClassroom, mdiChatOutline, mdiBullhornOutline } from '@mdi/js'
import { Icon } from '../../components/Primitives'

/**
 * PalliCore's visual system, from packages/core_ui: neumorphic clay
 * (canvas and surfaces share #EDEBE7; depth is only shadow), champagne
 * gold from AdminLook, and the per-feature card tints in AppColors.
 */
export const PK = {
  clay: '#EDEBE7',
  ink: '#303137',
  inkDeep: '#141414',
  mute: '#70727A',
  hint: '#9A9CA3',
  gold: '#C9A24A',
  goldLite: '#FFF4D4',
  accent: '#8B7355',
  success: '#3E8E5E',
  warning: '#C8872A',
  error: '#B4473E',
  // AppColors card tints
  classroom: '#8B7355',
  teacher: '#5B4A3A',
  student: '#5E7A5A',
  announcement: '#C48A3A',
  bus: '#7A5A48',
  event: '#6A5A8C',
  fee: '#3F6B6A',
  attendance: '#4E6B5A',
  leave: '#8A5A4A',
  academics: '#6B5A3A',
  exam: '#4A5A7A',
  admission: '#5A6B4A',
}

export function CoreScreen({ children, style, nav }: { children: ReactNode; style?: CSSProperties; nav?: 'home' | 'classes' | 'messages' | 'announcements' }) {
  return (
    <div className="pk absolute inset-0 overflow-hidden" style={style}>
      <CoreStatusBar />
      <div className="absolute inset-x-0 bottom-0 top-[40px] @[700px]:top-[32px]">{children}</div>
      {nav && <CoreNav active={nav} />}
    </div>
  )
}

function CoreStatusBar() {
  return (
    <div className="absolute inset-x-0 top-0 z-40 flex h-[40px] items-center justify-between px-7 pt-2 text-[14px] font-semibold @[700px]:h-[32px] @[700px]:pt-0" style={{ color: PK.ink }}>
      <span>9:41</span>
      <span className="flex items-center gap-1">
        <Icon path={mdiSignalCellular3} size={16} color={PK.ink} />
        <Icon path={mdiWifi} size={16} color={PK.ink} />
        <Icon path={mdiBattery} size={19} color={PK.ink} className="rotate-90" />
      </span>
    </div>
  )
}

/** SoftPageHeader with the admin/teacher actions. */
export function PageHeader({ title, sub, actions = true }: { title: string; sub?: string; actions?: boolean }) {
  return (
    <div className="flex items-center justify-between px-5 pb-2 pt-3 @[700px]:px-8">
      <div>
        <span className="block text-[26px] font-bold tracking-[-0.6px]" style={{ color: PK.ink }}>
          {title}
        </span>
        {sub && (
          <span className="text-[13px]" style={{ color: PK.mute }}>
            {sub}
          </span>
        )}
      </div>
      {actions && (
        <div className="flex gap-3">
          <span className="soft2 relative flex h-11 w-11 items-center justify-center rounded-full">
            <Icon path={mdiBellOutline} size={21} color={PK.ink} />
            <span className="absolute right-2 top-2 h-2 w-2 rounded-full" style={{ background: PK.gold }} />
          </span>
          <span className="flex h-11 w-11 items-center justify-center rounded-full">
            <Icon path={mdiLogout} size={20} color={PK.mute} />
          </span>
        </div>
      )}
    </div>
  )
}

export function IconWell({ path, color = PK.gold, size = 40 }: { path: string; color?: string; size?: number }) {
  return (
    <span className="soft-in flex shrink-0 items-center justify-center rounded-[14px]" style={{ width: size, height: size }}>
      <Icon path={path} size={size * 0.5} color={color} />
    </span>
  )
}

export function Pill({ children, color }: { children: ReactNode; color: string }) {
  return (
    <span className="inline-flex items-center rounded-full px-2.5 py-[3px] text-[11px] font-bold" style={{ background: `${color}1f`, color }}>
      {children}
    </span>
  )
}

/** NeoAnalogClock: a bezel raised out of the clay, hands at 9:41. */
export function AnalogClock({ size = 130 }: { size?: number }) {
  const hour = (9 + 41 / 60) * 30
  const minute = 41 * 6
  return (
    <span className="soft3 relative block shrink-0 rounded-full" style={{ width: size, height: size }}>
      <span className="soft-in absolute rounded-full" style={{ inset: size * 0.08 }} />
      <svg viewBox="0 0 100 100" className="absolute inset-0">
        {Array.from({ length: 12 }).map((_, i) => {
          const a = (i * 30 * Math.PI) / 180
          const major = i % 3 === 0
          const r1 = major ? 32 : 34
          return (
            <line key={i} x1={50 + Math.sin(a) * r1} y1={50 - Math.cos(a) * r1} x2={50 + Math.sin(a) * 37} y2={50 - Math.cos(a) * 37} stroke={major ? PK.ink : PK.hint} strokeWidth={major ? 2 : 1.2} strokeLinecap="round" />
          )
        })}
        <line x1="50" y1="50" x2="50" y2="31" stroke={PK.ink} strokeWidth="3.2" strokeLinecap="round" transform={`rotate(${hour} 50 50)`} />
        <line x1="50" y1="50" x2="50" y2="22" stroke={PK.ink} strokeWidth="2" strokeLinecap="round" transform={`rotate(${minute} 50 50)`} />
        <circle cx="50" cy="50" r="3.4" fill={PK.gold} />
      </svg>
    </span>
  )
}

/** NeoClockCard — greeting, clock and date, as on both home screens. */
export function ClockCard({ subtitle, title, compact }: { subtitle: string; title: string; compact?: boolean }) {
  return (
    <div className="soft3 mx-5 mb-4 mt-2 rounded-[32px] p-5 @[700px]:mx-0">
      <span className="block text-[14px]" style={{ color: PK.mute }}>
        {subtitle}
      </span>
      <span className="mt-1 block text-[24px] font-bold leading-tight tracking-[-0.6px]" style={{ color: PK.ink }}>
        {title}
      </span>
      <div className="mt-4 flex items-center gap-5">
        <AnalogClock size={compact ? 104 : 122} />
        <div>
          <span className="block text-[11px] font-semibold tracking-[1.6px]" style={{ color: PK.mute }}>
            FRIDAY
          </span>
          <span className="block text-[48px] font-extrabold leading-[0.95] tracking-[-1.6px]" style={{ color: PK.ink }}>
            25
          </span>
          <span className="block text-[15px] font-semibold" style={{ color: PK.ink }}>
            September 2026
          </span>
        </div>
      </div>
    </div>
  )
}

const NAV = [
  { id: 'home', label: 'Home', p: mdiHome },
  { id: 'classes', label: 'Classes', p: mdiGoogleClassroom },
  { id: 'messages', label: 'Messages', p: mdiChatOutline },
  { id: 'announcements', label: 'Announcements', p: mdiBullhornOutline },
] as const

/** NeoBottomNav — the teacher shell's four destinations. */
export function CoreNav({ active }: { active: string }) {
  return (
    <div className="soft1 absolute bottom-4 left-1/2 z-30 flex w-[calc(100%-32px)] max-w-[520px] -translate-x-1/2 items-center justify-around rounded-[28px] px-2 py-2">
      {NAV.map((n) => {
        const on = n.id === active
        return (
          <span key={n.id} className={`flex flex-col items-center gap-1 rounded-[20px] px-3 py-1.5 ${on ? 'soft-in' : ''}`}>
            <Icon path={n.p} size={22} color={on ? PK.gold : PK.mute} />
            <span className="text-[11px] font-semibold" style={{ color: on ? PK.ink : PK.mute }}>
              {n.label}
            </span>
          </span>
        )
      })}
    </div>
  )
}
