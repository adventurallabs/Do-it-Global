import { useEffect, useRef, type AnchorHTMLAttributes, type ReactNode } from 'react'
import { gsap } from '../animations/gsap'
import { useFinePointer } from '../hooks/useMediaQuery'
import { useReducedMotion } from '../hooks/useReducedMotion'

type Props = AnchorHTMLAttributes<HTMLAnchorElement> & {
  children: ReactNode
  variant?: 'solid' | 'ghost' | 'violet' | 'orange'
  strength?: number
}

const styles = {
  solid: 'bg-bone text-ink hover:bg-white',
  ghost: 'border border-line text-bone hover:border-bone/40 bg-white/[0.02]',
  violet:
    'text-white bg-[linear-gradient(135deg,#9a63dd,#7440b8_55%,#5a2896)] shadow-[0_18px_50px_-18px_rgba(129,73,193,0.8),inset_0_1px_0_rgba(255,255,255,0.25)]',
  // Nuvara: the mark's orange, deepened to clay600 so white text stays readable.
  orange:
    'text-white bg-[linear-gradient(135deg,#f0703f,#d9481a_55%,#b8380f)] shadow-[0_18px_50px_-18px_rgba(234,80,30,0.8),inset_0_1px_0_rgba(255,255,255,0.25)]',
}

/** A link that leans toward the pointer. A plain link on touch / reduced motion. */
export function MagneticButton({ children, variant = 'solid', strength = 0.32, className = '', ...rest }: Props) {
  const ref = useRef<HTMLAnchorElement>(null)
  const label = useRef<HTMLSpanElement>(null)
  const fine = useFinePointer()
  const reduced = useReducedMotion()

  useEffect(() => {
    const el = ref.current
    if (!el || !label.current || !fine || reduced) return
    const xTo = gsap.quickTo(el, 'x', { duration: 0.9, ease: 'expo.out' })
    const yTo = gsap.quickTo(el, 'y', { duration: 0.9, ease: 'expo.out' })
    const lx = gsap.quickTo(label.current, 'x', { duration: 0.9, ease: 'expo.out' })
    const ly = gsap.quickTo(label.current, 'y', { duration: 0.9, ease: 'expo.out' })
    const move = (e: PointerEvent) => {
      const r = el.getBoundingClientRect()
      const dx = e.clientX - (r.left + r.width / 2)
      const dy = e.clientY - (r.top + r.height / 2)
      xTo(dx * strength)
      yTo(dy * strength)
      lx(dx * strength * 0.35)
      ly(dy * strength * 0.35)
    }
    const leave = () => {
      xTo(0)
      yTo(0)
      lx(0)
      ly(0)
    }
    el.addEventListener('pointermove', move)
    el.addEventListener('pointerleave', leave)
    return () => {
      el.removeEventListener('pointermove', move)
      el.removeEventListener('pointerleave', leave)
    }
  }, [fine, reduced, strength])

  return (
    <a
      ref={ref}
      data-cursor="link"
      className={`group relative inline-flex items-center gap-3 whitespace-nowrap rounded-full px-7 py-4 text-[0.95rem] font-medium tracking-[-0.01em] transition-colors duration-500 ${styles[variant]} ${className}`}
      {...rest}
    >
      <span ref={label} className="relative inline-flex items-center gap-3">
        {children}
      </span>
    </a>
  )
}

export function Arrow({ className = '', diagonal = false }: { className?: string; diagonal?: boolean }) {
  return (
    <svg
      viewBox="0 0 20 20"
      aria-hidden
      className={`h-4 w-4 transition-transform duration-500 ease-[var(--ease-out-expo)] ${diagonal ? '-rotate-45 group-hover:rotate-0' : 'group-hover:translate-x-1'} ${className}`}
    >
      <path d="M3 10h13M11 4.5 16.5 10 11 15.5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
