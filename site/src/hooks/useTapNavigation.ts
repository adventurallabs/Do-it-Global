import { useEffect, type RefObject } from 'react'
import { getLenis } from './useScrollDirector'
import { collectStops } from '../lib/tapStops'

/** Anything a tap should keep doing its own job on. */
const INTERACTIVE =
  'a, button, input, textarea, select, label, summary, video, audio, iframe, [role="button"], [role="link"], [role="tab"], [contenteditable], [data-no-tap], header, dialog'

/**
 * Tap (or click) on an empty spot to step through the page: the right half
 * plays the next animation step, the left half goes back one. Links,
 * buttons and the nav keep working as usual; swipes and wheel scrolling are
 * untouched (a swipe never produces a click).
 */
export function useTapNavigation(root: RefObject<HTMLElement | null>) {
  useEffect(() => {
    // Rapid taps chain from the previous tap's destination, not from
    // wherever the smooth scroll happens to be mid-flight.
    let pending: number | null = null

    const onClick = (e: MouseEvent) => {
      const el = root.current
      if (!el || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return
      const target = e.target as Element | null
      if (!target || target.closest(INTERACTIVE)) return
      if (window.getSelection()?.toString()) return

      const lenis = getLenis()
      const now = window.scrollY
      const from = pending ?? now
      const stops = collectStops(el)
      const dir = e.clientX >= window.innerWidth / 2 ? 1 : -1
      const to = dir > 0 ? stops.find((y) => y > from + 4) : [...stops].reverse().find((y) => y < from - 4)
      if (to === undefined) return

      pending = to
      const done = () => {
        if (pending === to) pending = null
      }
      if (lenis) {
        const dist = Math.abs(to - now) / window.innerHeight
        lenis.scrollTo(to, { duration: Math.min(1.8, 0.9 + dist * 0.35), onComplete: done, force: true })
      } else {
        window.scrollTo({ top: to, behavior: 'auto' })
        done()
      }
    }

    // A wheel or swipe takes over from any tap still in flight. (Not
    // touchstart: that fires for the tap itself.)
    // The wheel is Lenis's own input: it simply retargets from there.
    const onWheel = () => (pending = null)
    const onSwipe = () => {
      if (pending === null) return
      pending = null
      // Lenis leaves touch to the browser, so stop its tap animation or it
      // would keep pulling against the finger.
      const lenis = getLenis()
      lenis?.stop()
      lenis?.start()
    }
    document.addEventListener('click', onClick)
    window.addEventListener('wheel', onWheel, { passive: true })
    window.addEventListener('touchmove', onSwipe, { passive: true })
    return () => {
      document.removeEventListener('click', onClick)
      window.removeEventListener('wheel', onWheel)
      window.removeEventListener('touchmove', onSwipe)
    }
  }, [root])
}
