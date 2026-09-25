import { useEffect } from 'react'
import Lenis from 'lenis'
import { gsap, ScrollTrigger } from '../animations/gsap'
import { measureSections, scroll } from '../lib/scrollStore'
import { damp } from '../lib/math'

let lenisInstance: Lenis | null = null
export const getLenis = () => lenisInstance

/**
 * Owns the page's scroll loop: Lenis smoothing (skipped for reduced motion),
 * ScrollTrigger sync, section measurement and pointer smoothing — all on
 * GSAP's single ticker so DOM and WebGL read the same frame's values.
 */
export function useScrollDirector(reduced: boolean) {
  useEffect(() => {
    let lenis: Lenis | null = null
    if (!reduced) {
      lenis = new Lenis({
        duration: 1.15,
        easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
        smoothWheel: true,
        wheelMultiplier: 0.95,
        anchors: true,
      })
      lenisInstance = lenis
      lenis.on('scroll', (e: Lenis) => {
        scroll.velocity = e.velocity
        scroll.direction = e.direction === -1 ? -1 : 1
        ScrollTrigger.update()
      })
    }

    const onPointer = (e: PointerEvent) => {
      scroll.pointer.x = (e.clientX / window.innerWidth) * 2 - 1
      scroll.pointer.y = -((e.clientY / window.innerHeight) * 2 - 1)
    }
    window.addEventListener('pointermove', onPointer, { passive: true })

    let last = performance.now()
    const tick = (time: number) => {
      lenis?.raf(time * 1000)
      const now = performance.now()
      const dt = Math.min(0.1, (now - last) / 1000)
      last = now
      scroll.y = window.scrollY
      if (!lenis) scroll.velocity = 0
      measureSections()
      const p = scroll.pointer
      p.sx = damp(p.sx, p.x, 3.2, dt)
      p.sy = damp(p.sy, p.y, 3.2, dt)
    }
    gsap.ticker.add(tick)
    gsap.ticker.lagSmoothing(0)

    // Fonts and lazy media change layout; re-measure triggers once settled.
    const refresh = () => ScrollTrigger.refresh()
    document.fonts?.ready.then(refresh)
    window.addEventListener('load', refresh)

    return () => {
      gsap.ticker.remove(tick)
      window.removeEventListener('pointermove', onPointer)
      window.removeEventListener('load', refresh)
      lenis?.destroy()
      lenisInstance = null
    }
  }, [reduced])
}

export function scrollToTarget(target: string | HTMLElement) {
  const el = typeof target === 'string' ? document.querySelector<HTMLElement>(target) : target
  if (!el) return
  if (lenisInstance) lenisInstance.scrollTo(el, { duration: 1.6 })
  else el.scrollIntoView({ behavior: 'auto' })
}
