import type { CSSProperties, ReactNode } from 'react'

export function SectionLabel({ index, children, className = '', accent }: { index?: string; children: string; className?: string; accent?: string }) {
  return (
    <p className={`t-label flex items-center gap-3 ${className}`}>
      {index && <span style={{ color: accent }}>{index}</span>}
      <span aria-hidden className="h-px w-8 bg-current opacity-40" />
      <span>{children}</span>
    </p>
  )
}

export function ScrollCue({ label = 'Scroll' }: { label?: string }) {
  return (
    <div className="flex flex-col items-center gap-3" aria-hidden>
      <span className="t-label text-[0.62rem]">{label}</span>
      <span className="relative block h-12 w-px overflow-hidden bg-bone/10">
        <span className="scroll-cue absolute inset-x-0 top-0 h-1/2 bg-bone/70" />
      </span>
    </div>
  )
}

export function GlassPanel({ children, className = '', style }: { children: ReactNode; className?: string; style?: CSSProperties }) {
  return (
    <div className={`glass rounded-[28px] ${className}`} style={style}>
      {children}
    </div>
  )
}

/** Material Design icon from an @mdi/js path — the recreated app screens use
 * the same Material icon language as the Flutter apps. */
export function Icon({ path, size = 20, color = 'currentColor', className, title }: { path: string; size?: number; color?: string; className?: string; title?: string }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} className={className} aria-hidden={title ? undefined : true} role={title ? 'img' : undefined}>
      {title && <title>{title}</title>}
      <path d={path} fill={color} />
    </svg>
  )
}
