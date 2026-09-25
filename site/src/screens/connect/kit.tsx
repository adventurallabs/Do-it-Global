import type { CSSProperties, ReactNode } from 'react'
import {
  mdiAccount,
  mdiAccountOutline,
  mdiArrowLeft,
  mdiBattery,
  mdiBellOutline,
  mdiBookOpenPageVariant,
  mdiBookOpenVariant,
  mdiChartLineVariant,
  mdiChat,
  mdiChatOutline,
  mdiSignalCellular3,
  mdiWhiteBalanceSunny,
  mdiWifi,
} from '@mdi/js'
import { Icon } from '../../components/Primitives'

/**
 * PalliConnect's design system, recreated from lib/core/design_system:
 * AppColors, the BrandAtmosphere glow orbs, PremiumCard, the floating glass
 * NavigationBar in AppShell, and the Fraunces / Outfit type pairing.
 */
export const PC = {
  midnight: '#07111F',
  deepNavy: '#0A1628',
  royalBlue: '#1E4FD8',
  primaryBlue: '#2F6BFF',
  skyBlue: '#3EC6FF',
  ice: '#EAF4FF',
  leafGreen: '#22C55E',
  heart: '#F43F5E',
  charcoal: '#102037',
  grey200: '#D7E4F4',
  grey400: '#8AA0BB',
  grey500: '#6B829C',
  grey600: '#4A6078',
  success: '#16A34A',
  successSoft: '#DCFCE7',
  successOn: '#166534',
  warning: '#D97706',
  warningSoft: '#FEF3C7',
  warningOn: '#92400E',
  error: '#E11D48',
  errorSoft: '#FFE4E6',
  errorOn: '#9F1239',
  info: '#2563EB',
  infoSoft: '#DBEAFE',
  infoOn: '#1E40AF',
  star: '#F5A524',
}

export const heroGradient = `linear-gradient(135deg, ${PC.midnight}, #10275a 50%, #2a8eeb)`
export const brandSweep = (a = 1) => `linear-gradient(135deg, rgba(47,107,255,${a}), rgba(62,198,255,${a}), rgba(34,197,94,${a * 0.9}))`

export function ConnectScreen({ children, nav, navLabels, bare, style }: { children: ReactNode; nav?: TabId; navLabels?: Partial<Record<TabId, string>>; bare?: boolean; style?: CSSProperties }) {
  return (
    <div className="pc absolute inset-0 overflow-hidden" style={style}>
      <div className="absolute inset-0" style={{ background: 'linear-gradient(135deg,#F7FBFF,#EAF4FF 55%,#F3FBF6)' }} />
      {!bare && (
        <>
          <Orb x={250} y={-90} size={280} color="47,107,255" a={0.14} />
          <Orb x={-110} y={220} size={240} color="34,197,94" a={0.1} />
          <Orb x={270} y={640} size={200} color="62,198,255" a={0.08} />
        </>
      )}
      <StatusBar />
      <div className="absolute inset-x-0 bottom-0 top-[54px]">{children}</div>
      {nav && <BottomNav active={nav} labels={navLabels} />}
    </div>
  )
}

function Orb({ x, y, size, color, a }: { x: number; y: number; size: number; color: string; a: number }) {
  return (
    <div
      className="pointer-events-none absolute rounded-full"
      style={{ left: x, top: y, width: size, height: size, background: `radial-gradient(circle, rgba(${color},${a}), rgba(${color},0) 70%)` }}
    />
  )
}

export function StatusBar({ dark }: { dark?: boolean }) {
  const c = dark ? '#fff' : PC.charcoal
  return (
    <div className="absolute inset-x-0 top-0 z-40 flex h-[54px] items-center justify-between px-8 pt-1 text-[15px] font-semibold" style={{ color: c }}>
      <span style={{ fontFamily: 'system-ui, sans-serif' }}>9:41</span>
      <span className="flex items-center gap-1">
        <Icon path={mdiSignalCellular3} size={17} color={c} />
        <Icon path={mdiWifi} size={17} color={c} />
        <Icon path={mdiBattery} size={20} color={c} className="rotate-90" />
      </span>
    </div>
  )
}

export type TabId = 'today' | 'diary' | 'messages' | 'progress' | 'profile'

const TABS: { id: TabId; label: string; icon: string; active: string }[] = [
  { id: 'today', label: 'Today', icon: mdiWhiteBalanceSunny, active: mdiWhiteBalanceSunny },
  { id: 'diary', label: 'Diary', icon: mdiBookOpenVariant, active: mdiBookOpenPageVariant },
  { id: 'messages', label: 'Messages', icon: mdiChatOutline, active: mdiChat },
  { id: 'progress', label: 'Progress', icon: mdiChartLineVariant, active: mdiChartLineVariant },
  { id: 'profile', label: 'Profile', icon: mdiAccountOutline, active: mdiAccount },
]

export function BottomNav({ active, labels }: { active: TabId; labels?: Partial<Record<TabId, string>> }) {
  return (
    <div
      className="absolute inset-x-4 bottom-3 z-30 flex h-[72px] items-center justify-around rounded-[32px] border"
      style={{
        borderColor: 'rgba(62,198,255,.35)',
        // Near-opaque instead of backdrop blur: a blur inside a scaled,
        // 3D-tilted device is a heavy GPU layer on phones and tablets.
        background: 'linear-gradient(135deg, rgba(255,255,255,.96), rgba(236,245,255,.93))',
        boxShadow: '0 12px 30px -12px rgba(16,32,55,.25)',
      }}
    >
      {TABS.map((t) => {
        const on = t.id === active
        return (
          <div key={t.id} className="flex w-[64px] flex-col items-center gap-1">
            <div className="flex h-[38px] items-center justify-center rounded-[14px] px-2" style={on ? { background: brandSweep(0.18) } : undefined}>
              <Icon path={on ? t.active : t.icon} size={on ? 22 : 24} color={on ? PC.primaryBlue : PC.grey500} />
            </div>
            <span className="block max-w-[66px] truncate text-center font-medium leading-none" style={{ color: on ? PC.primaryBlue : PC.grey600, fontSize: labels ? 9.5 : 11.5 }}>
              {labels?.[t.id] ?? t.label}
            </span>
          </div>
        )
      })}
    </div>
  )
}

export function Card({ children, className = '', style, luminous }: { children: ReactNode; className?: string; style?: CSSProperties; luminous?: boolean }) {
  return (
    <div
      className={`rounded-[24px] border p-4 ${className}`}
      style={{
        borderColor: 'rgba(47,107,255,.10)',
        background: 'linear-gradient(135deg, rgba(255,255,255,.92), rgba(255,255,255,.74))',
        boxShadow: luminous ? '0 16px 36px -14px rgba(47,107,255,.32)' : '0 10px 26px -16px rgba(16,32,55,.22)',
        ...style,
      }}
    >
      {children}
    </div>
  )
}

export function AppBar({ title, trailing }: { title: string; trailing?: ReactNode }) {
  return (
    <div className="flex h-[56px] items-center gap-3 px-3">
      <span className="flex h-10 w-10 items-center justify-center">
        <Icon path={mdiArrowLeft} size={24} color={PC.charcoal} />
      </span>
      <span className="pc-display flex-1 text-[20px] font-semibold tracking-[-0.2px]" style={{ color: PC.charcoal }}>
        {title}
      </span>
      {trailing}
    </div>
  )
}

export function SectionHeader({ title, action }: { title: string; action?: string }) {
  return (
    <div className="mb-2.5 flex items-end justify-between">
      <span className="pc-display text-[20px] font-semibold tracking-[-0.2px]" style={{ color: PC.charcoal }}>
        {title}
      </span>
      {action && (
        <span className="text-[13px] font-semibold" style={{ color: PC.primaryBlue }}>
          {action}
        </span>
      )}
    </div>
  )
}

type Tone = 'success' | 'warning' | 'error' | 'info'
export function Badge({ tone, children }: { tone: Tone; children: ReactNode }) {
  const map = {
    success: [PC.successSoft, PC.successOn],
    warning: [PC.warningSoft, PC.warningOn],
    error: [PC.errorSoft, PC.errorOn],
    info: [PC.infoSoft, PC.infoOn],
  } as const
  const [bg, fg] = map[tone]
  return (
    <span className="inline-flex items-center rounded-full px-2.5 py-[3px] text-[11.5px] font-semibold" style={{ background: bg, color: fg }}>
      {children}
    </span>
  )
}

export function IconTile({ path, color, size = 40, iconSize = 22 }: { path: string; color: string; size?: number; iconSize?: number }) {
  return (
    <span className="flex shrink-0 items-center justify-center rounded-[12px]" style={{ width: size, height: size, background: `${color}24` }}>
      <Icon path={path} size={iconSize} color={color} />
    </span>
  )
}

export function Bell({ count }: { count: number }) {
  return (
    <span className="relative flex h-11 w-11 items-center justify-center rounded-full bg-white/80 shadow-[0_6px_16px_-8px_rgba(16,32,55,.35)]">
      <Icon path={mdiBellOutline} size={23} color={PC.charcoal} />
      {count > 0 && (
        <span className="absolute right-1.5 top-1.5 flex h-[17px] min-w-[17px] items-center justify-center rounded-full px-1 text-[10px] font-bold text-white" style={{ background: PC.error }}>
          {count}
        </span>
      )}
    </span>
  )
}

export function Avatar({ initials, size = 40, ring }: { initials: string; size?: number; ring?: boolean }) {
  return (
    <span
      className="flex shrink-0 items-center justify-center rounded-full text-white"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.36,
        fontWeight: 600,
        background: `linear-gradient(135deg, ${PC.royalBlue}, ${PC.skyBlue})`,
        boxShadow: ring ? `0 0 0 3px #fff, 0 0 0 5px ${PC.skyBlue}55` : undefined,
      }}
    >
      {initials}
    </span>
  )
}
