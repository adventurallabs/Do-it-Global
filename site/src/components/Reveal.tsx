import { useLayoutEffect, useRef, type ReactNode } from 'react'
import { gsap } from '../animations/gsap'
import { useReducedMotion } from '../hooks/useReducedMotion'

type Props = {
  children: ReactNode
  className?: string
  delay?: number
  y?: number
  /** Animate direct children one after another. */
  stagger?: number
}

/** Fade-and-rise on first entry. Used for supporting copy and small UI. */
export function Reveal({ children, className, delay = 0, y = 28, stagger }: Props) {
  const ref = useRef<HTMLDivElement>(null)
  const reduced = useReducedMotion()

  useLayoutEffect(() => {
    const el = ref.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      const targets = stagger ? Array.from(el.children) : el
      gsap.fromTo(
        targets,
        { y, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 1.4,
          ease: 'expo.out',
          delay,
          stagger,
          scrollTrigger: { trigger: el, start: 'top 90%', once: true },
        },
      )
    }, el)
    return () => ctx.revert()
  }, [reduced, delay, y, stagger])

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  )
}
