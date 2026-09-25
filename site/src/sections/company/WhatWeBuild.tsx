import { RevealText } from '../../components/RevealText'
import { Reveal } from '../../components/Reveal'
import { SectionLabel } from '../../components/Primitives'
import { useSection } from '../../hooks/useSection'
import { BUILD } from '../../data/company'

export function WhatWeBuild() {
  const ref = useSection<HTMLElement>('build')
  return (
    <section ref={ref} id="build" className="relative flex min-h-[150svh] items-center">
      <div className="mx-auto w-full max-w-[1600px] px-5 py-32 sm:px-8 md:px-12">
        <div className="max-w-[46rem] pt-[38svh] md:pt-0">
          <SectionLabel index="01">{BUILD.label}</SectionLabel>
          <RevealText text={BUILD.heading} className="t-h1 mt-8 text-bone" />
          <Reveal className="mt-10 max-w-[36rem]">
            <p className="t-lead">{BUILD.body}</p>
          </Reveal>

          <Reveal stagger={0.1} className="mt-16 border-t border-line">
            {BUILD.capabilities.map((c, i) => (
              <div key={c.title} className="grid grid-cols-[3rem_1fr] gap-4 border-b border-line py-6 md:grid-cols-[4rem_14rem_1fr] md:gap-6">
                <span className="t-label pt-1.5">0{i + 1}</span>
                <h3 className="text-[1.15rem] font-medium tracking-[-0.02em] text-bone">{c.title}</h3>
                <p className="col-start-2 text-[0.98rem] leading-relaxed text-mute md:col-start-3">{c.text}</p>
              </div>
            ))}
          </Reveal>
        </div>
      </div>
    </section>
  )
}
