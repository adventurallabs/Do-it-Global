import { useEffect, useRef, useState, type ReactNode } from 'react'
import { scroll } from '../lib/scrollStore'
import { scrollToTarget } from '../hooks/useScrollDirector'

export type NavLink = { label: string; href: string; external?: boolean }

type Props = {
  brand: ReactNode
  brandHref: string
  links: NavLink[]
  cta?: ReactNode
}

/** Hides on the way down, returns on the way up. */
export function Nav({ brand, brandHref, links, cta }: Props) {
  const [hidden, setHidden] = useState(false)
  const [solid, setSolid] = useState(false)
  const [open, setOpen] = useState(false)
  const last = useRef(0)

  // The menu owns the screen while open: Escape closes it.
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open])

  useEffect(() => {
    let raf = 0
    const loop = () => {
      const y = scroll.y
      const dy = y - last.current
      if (Math.abs(dy) > 6) {
        setHidden(dy > 0 && y > 240)
        last.current = y
      }
      setSolid(y > 40)
      raf = requestAnimationFrame(loop)
    }
    raf = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(raf)
  }, [])

  const onClick = (e: React.MouseEvent<HTMLAnchorElement>, l: NavLink) => {
    setOpen(false)
    if (l.external || !l.href.startsWith('#')) return
    e.preventDefault()
    scrollToTarget(l.href)
  }

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-transform duration-700 ease-[var(--ease-out-expo)] ${hidden && !open ? '-translate-y-full' : 'translate-y-0'}`}
    >
      <div
        className={`mx-auto flex max-w-[1600px] items-center justify-between px-5 py-4 transition-[background-color,backdrop-filter] duration-700 sm:px-8 md:px-12 md:py-5 ${
          solid || open ? 'bg-ink/85 pointer-fine:bg-ink/55 pointer-fine:backdrop-blur-xl' : ''
        }`}
      >
        <a href={brandHref} className="flex items-center gap-3" aria-label="Home">
          {brand}
        </a>
        <nav aria-label="Primary" className="hidden items-center gap-8 lg:flex">
          {links.map((l) => (
            <a
              key={l.label}
              href={l.href}
              onClick={(e) => onClick(e, l)}
              target={l.external ? '_blank' : undefined}
              rel={l.external ? 'noopener' : undefined}
              className="group relative text-[0.86rem] tracking-[-0.01em] text-bone/70 transition-colors hover:text-bone"
            >
              {l.label}
              {l.external && <span aria-hidden className="ml-1 inline-block text-bone/40">↗</span>}
              <span className="absolute -bottom-1 left-0 h-px w-full origin-right scale-x-0 bg-bone/60 transition-transform duration-500 ease-[var(--ease-out-expo)] group-hover:origin-left group-hover:scale-x-100" />
            </a>
          ))}
        </nav>
        <div className="flex items-center gap-3">
          {cta}
          <button
            type="button"
            className="flex h-10 w-10 items-center justify-center rounded-full border border-line text-bone lg:hidden"
            aria-expanded={open}
            aria-controls="mobile-menu"
            aria-label={open ? 'Close menu' : 'Open menu'}
            onClick={() => setOpen((o) => !o)}
          >
            <span className="relative block h-3 w-4">
              <span className={`absolute left-0 h-px w-4 bg-current transition-transform duration-300 ${open ? 'top-1.5 rotate-45' : 'top-0'}`} />
              <span className={`absolute left-0 top-1.5 h-px w-4 bg-current transition-opacity duration-300 ${open ? 'opacity-0' : ''}`} />
              <span className={`absolute left-0 h-px w-4 bg-current transition-transform duration-300 ${open ? 'top-1.5 -rotate-45' : 'top-3'}`} />
            </span>
          </button>
        </div>
      </div>
      {open && (
        <nav id="mobile-menu" aria-label="Menu" className="border-t border-line bg-ink/95 px-5 pb-8 pt-4 sm:px-8 lg:hidden">
          <ul className="mx-auto flex max-w-[1600px] flex-col">
            {links.map((l) => (
              <li key={l.label} className="border-b border-line/60">
                <a
                  href={l.href}
                  onClick={(e) => onClick(e, l)}
                  target={l.external ? '_blank' : undefined}
                  rel={l.external ? 'noopener' : undefined}
                  className="flex items-center justify-between py-4 text-[1.15rem] tracking-[-0.01em] text-bone"
                >
                  {l.label}
                  <span aria-hidden className="text-bone/40">{l.external ? '↗' : '→'}</span>
                </a>
              </li>
            ))}
          </ul>
        </nav>
      )}
    </header>
  )
}

export function DigMark({ className = '' }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden>
      <circle cx="32" cy="32" r="15" fill="none" stroke="currentColor" strokeWidth="3.2" />
      <ellipse cx="32" cy="32" rx="24" ry="8.5" fill="none" stroke="currentColor" strokeOpacity=".5" strokeWidth="2" transform="rotate(-24 32 32)" />
      <circle cx="51.6" cy="23.6" r="3.6" fill="#B79BFF" />
    </svg>
  )
}
