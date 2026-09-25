import { useLayoutEffect, useRef } from 'react'
import { gsap } from '../animations/gsap'
import { useReducedMotion } from '../hooks/useReducedMotion'

type Props = {
  text: string
  as?: 'h1' | 'h2' | 'h3' | 'p' | 'div'
  className?: string
  /** Seconds before the first word moves. */
  delay?: number
  stagger?: number
  /** Play on mount instead of when scrolled into view. */
  immediate?: boolean
  /** Extra class per word (e.g. a gradient on one word). */
  wordClassName?: (word: string, index: number) => string | undefined
}

/**
 * Display type that rises out of a per-word mask. Lines split on "\n".
 * Screen readers get the plain sentence through aria-label.
 */
export function RevealText({ text, as = 'h2', className, delay = 0, stagger = 0.055, immediate = false, wordClassName }: Props) {
  const Tag = as as 'h2'
  const ref = useRef<HTMLHeadingElement>(null)
  const reduced = useReducedMotion()

  useLayoutEffect(() => {
    const el = ref.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      const words = el.querySelectorAll('.rv-word')
      // Explicit y:0 on both ends: GSAP must never inherit a stale pixel
      // offset parsed from a previous run's matrix.
      const from = { yPercent: 118, y: 0, rotate: 3 }
      const vars: gsap.TweenVars = { yPercent: 0, y: 0, rotate: 0, duration: 1.35, ease: 'expo.out', stagger, delay, clearProps: 'transform' }
      if (immediate) gsap.fromTo(words, from, vars)
      else gsap.fromTo(words, from, { ...vars, scrollTrigger: { trigger: el, start: 'top 88%', once: true } })
    }, el)
    return () => ctx.revert()
  }, [reduced, immediate, delay, stagger, text])

  let i = 0
  return (
    <Tag ref={ref} className={className} aria-label={text.replace(/\n/g, ' ')}>
      {text.split('\n').map((line, li) => {
        const words = line.split(' ')
        return (
          <span key={li} className="block" aria-hidden>
            {words.map((word, wi) => {
              const idx = i++
              return (
                <span key={wi} className="inline-block overflow-clip pb-[0.1em] -mb-[0.1em] align-top">
                  <span className={`rv-word ${wordClassName?.(word, idx) ?? ''}`}>{word}</span>
                  {wi < words.length - 1 ? ' ' : null}
                </span>
              )
            })}
          </span>
        )
      })}
    </Tag>
  )
}
