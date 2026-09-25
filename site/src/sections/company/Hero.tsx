import { useLayoutEffect, useRef } from 'react'
import { gsap } from '../../animations/gsap'
import { RevealText } from '../../components/RevealText'
import { ScrollCue } from '../../components/Primitives'
import { useSection } from '../../hooks/useSection'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { HERO } from '../../data/company'

export function Hero() {
  const sectionRef = useSection<HTMLElement>('hero')
  const inner = useRef<HTMLDivElement>(null)
  const reduced = useReducedMotion()

  useLayoutEffect(() => {
    const el = inner.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      gsap.from('[data-hero-fade]', { opacity: 0, y: 24, duration: 1.6, stagger: 0.12, delay: 0.9 })
      // As the camera pushes in, the type drifts up and away.
      gsap.to(el, {
        yPercent: -18,
        opacity: 0,
        ease: 'none',
        scrollTrigger: { trigger: el, start: 'top top', end: 'bottom top', scrub: true },
      })
    }, el)
    return () => ctx.revert()
  }, [reduced])

  return (
    <section ref={sectionRef} id="top" className="relative h-[100svh] min-h-[640px]">
      <div ref={inner} className="relative mx-auto flex h-full max-w-[1600px] flex-col justify-end px-5 pb-10 sm:px-8 md:px-12 md:pb-14">
        <div className="mb-6 flex items-end justify-between gap-8 md:mb-10">
          <p data-hero-fade className="t-label">Technologies</p>
          <p data-hero-fade className="t-label hidden md:block">
            Product company · Makers of Palli
          </p>
        </div>

        <h1 className="sr-only">Do It Global Technologies — {HERO.statement}</h1>
        <RevealText
          as="p"
          immediate
          delay={0.2}
          stagger={0.09}
          text="Do It Global"
          className="t-display -ml-[0.04em] text-bone"
        />

        <div className="mt-8 grid gap-8 md:mt-12 md:grid-cols-12 md:items-end">
          <RevealText
            as="p"
            immediate
            delay={0.55}
            stagger={0.03}
            text={HERO.statement}
            className="t-h3 max-w-[22ch] text-bone md:col-span-6"
          />
          <p data-hero-fade className="t-lead max-w-[40ch] md:col-span-4 md:col-start-8">
            {HERO.sub}
          </p>
          <div data-hero-fade className="hidden justify-end md:col-span-1 md:col-start-12 md:flex">
            <ScrollCue />
          </div>
        </div>
      </div>
    </section>
  )
}
