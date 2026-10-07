import { useLayoutEffect, useRef } from 'react'
import { gsap } from '../../animations/gsap'
import { SectionLabel } from '../../components/Primitives'
import { useSection } from '../../hooks/useSection'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { PRINCIPLES } from '../../data/company'

/** Three principles, one at a time, scrubbed by scroll while the field
 *  behind them turns from a ring into a globe. */
export function Philosophy() {
  const sectionRef = useSection<HTMLElement>('philosophy')
  const root = useRef<HTMLElement | null>(null)
  const reduced = useReducedMotion()

  useLayoutEffect(() => {
    const el = root.current
    if (!el || reduced) return
    const ctx = gsap.context(() => {
      const items = gsap.utils.toArray<HTMLElement>('[data-principle]')
      const ticks = gsap.utils.toArray<HTMLElement>('[data-tick]')
      const tl = gsap.timeline({
        defaults: { ease: 'none' },
        scrollTrigger: { trigger: el, start: 'top top', end: 'bottom bottom', scrub: 0.6 },
      })
      items.forEach((item, i) => {
        const words = item.querySelectorAll('[data-w]')
        const text = item.querySelectorAll('[data-text]')
        const at = i * 1.2
        tl.fromTo(words, { yPercent: 110, y: 0, opacity: 0 }, { yPercent: 0, y: 0, opacity: 1, stagger: 0.06, duration: 0.45, ease: 'power3.out' }, at)
        tl.fromTo(text, { y: 30, opacity: 0 }, { y: 0, opacity: 1, duration: 0.4, ease: 'power3.out' }, at + 0.15)
        tl.to(ticks[i], { scaleY: 1, duration: 1.2 }, at)
        if (i < items.length - 1) {
          tl.to(words, { yPercent: -110, opacity: 0, stagger: 0.04, duration: 0.35, ease: 'power2.in' }, at + 0.95)
          tl.to(text, { y: -20, opacity: 0, duration: 0.3, ease: 'power2.in' }, at + 0.95)
        }
      })
      tl.to({}, { duration: 0.4 })
    }, el)
    return () => ctx.revert()
  }, [reduced])

  const setRefs = (el: HTMLElement | null) => {
    root.current = el
    sectionRef(el)
  }

  if (reduced) {
    return (
      <section ref={setRefs} id="philosophy" className="relative px-5 py-40 sm:px-8 md:px-12">
        <div className="mx-auto max-w-[1600px]">
          <SectionLabel index="04">How we build</SectionLabel>
          <div className="mt-16 space-y-20">
            {PRINCIPLES.map((p) => (
              <div key={p.title}>
                <h3 className="t-h1 text-bone">{p.title}</h3>
                <p className="t-lead mt-6 max-w-[34rem]">{p.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    )
  }

  return (
    <section ref={setRefs} id="philosophy" className="relative h-[380svh]">
      <div className="sticky-stage">
        <div className="mx-auto flex h-full max-w-[1600px] flex-col justify-center px-5 sm:px-8 md:px-12">
          <SectionLabel index="04" className="absolute top-24 md:top-28">
            How we build
          </SectionLabel>

          <div className="relative flex gap-8 pt-[34svh] md:gap-14 md:pt-0">
            <div className="flex flex-col gap-2 pt-3" aria-hidden>
              {PRINCIPLES.map((p) => (
                <span key={p.title} className="relative block h-16 w-px bg-bone/15 md:h-24">
                  <span data-tick className="absolute inset-0 origin-top scale-y-0 bg-bone" />
                </span>
              ))}
            </div>

            <div className="relative min-h-[16rem] flex-1 md:min-h-[22rem]">
              {PRINCIPLES.map((p, i) => (
                <div key={p.title} data-principle className="absolute inset-0">
                  <p data-text className="t-label mb-6">
                    0{i + 1} / 0{PRINCIPLES.length}
                  </p>
                  <h3 className="t-h1 max-w-[12ch] text-bone" aria-label={p.title}>
                    {p.title.split(' ').map((w, wi) => (
                      <span key={wi} className="inline-block overflow-clip pb-[0.1em] -mb-[0.1em] align-top" aria-hidden>
                        <span data-w className="inline-block">
                          {w}
                          {' '}
                        </span>
                      </span>
                    ))}
                  </h3>
                  <p data-text className="t-lead mt-8 max-w-[30rem]">
                    {p.text}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
