import { useEffect, useRef } from 'react'
import { gsap } from '../animations/gsap'
import { useFinePointer } from '../hooks/useMediaQuery'
import { useReducedMotion } from '../hooks/useReducedMotion'

/**
 * A quiet trailing ring. The system cursor stays visible; this only adds
 * weight, and swells over links and anything marked data-cursor.
 */
export function Cursor() {
  const ring = useRef<HTMLDivElement>(null)
  const fine = useFinePointer()
  const reduced = useReducedMotion()

  useEffect(() => {
    const el = ring.current
    if (!el || !fine || reduced) return
    const xTo = gsap.quickTo(el, 'x', { duration: 0.55, ease: 'power3.out' })
    const yTo = gsap.quickTo(el, 'y', { duration: 0.55, ease: 'power3.out' })
    let shown = false
    const move = (e: PointerEvent) => {
      if (!shown) {
        gsap.to(el, { opacity: 1, duration: 0.6 })
        shown = true
      }
      xTo(e.clientX)
      yTo(e.clientY)
      const hot = (e.target as HTMLElement | null)?.closest?.('[data-cursor], a, button')
      el.dataset.hot = hot ? '1' : ''
    }
    const leave = () => {
      gsap.to(el, { opacity: 0, duration: 0.4 })
      shown = false
    }
    window.addEventListener('pointermove', move, { passive: true })
    document.documentElement.addEventListener('pointerleave', leave)
    return () => {
      window.removeEventListener('pointermove', move)
      document.documentElement.removeEventListener('pointerleave', leave)
    }
  }, [fine, reduced])

  if (!fine || reduced) return null
  return (
    <div ref={ring} aria-hidden className="pointer-events-none fixed left-0 top-0 z-[70] opacity-0 mix-blend-difference">
      <div className="cursor-ring -ml-4 -mt-4 h-8 w-8 rounded-full border border-bone/50" />
    </div>
  )
}
