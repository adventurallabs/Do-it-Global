import { lazy, Suspense } from 'react'
import { Nav, DigMark } from '../components/Nav'
import { Cursor } from '../components/Cursor'
import { MagneticButton, Arrow } from '../components/MagneticButton'
import { useScrollDirector } from '../hooks/useScrollDirector'
import { useReducedMotion } from '../hooks/useReducedMotion'
import { Hero } from '../sections/company/Hero'
import { WhatWeBuild } from '../sections/company/WhatWeBuild'
import { ProductPortal } from '../sections/company/ProductPortal'
import { Philosophy } from '../sections/company/Philosophy'
import { Vision } from '../sections/company/Vision'
import { SITE } from '../data/site'
import { NUVARA, PRODUCT } from '../data/company'

// WebGL arrives after the first paint; the page is complete without it.
const SceneCanvas = lazy(() => import('../components/SceneCanvas'))
const CompanyScene = lazy(() => import('../three/company/CompanyScene'))

export function CompanyPage() {
  const reduced = useReducedMotion()
  useScrollDirector(reduced)

  return (
    <div className="grain">
      <a href="#build" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[80] focus:rounded-full focus:bg-bone focus:px-4 focus:py-2 focus:text-ink">
        Skip to content
      </a>
      <Suspense fallback={null}>
        <SceneCanvas background="#08090c" reduced={reduced}>
          <CompanyScene />
        </SceneCanvas>
      </Suspense>
      <div aria-hidden className="vignette pointer-events-none fixed inset-0 z-[1]" />
      <Cursor />
      <Nav
        brand={
          <>
            <DigMark className="h-8 w-8 text-bone" />
            <span className="text-[0.95rem] font-medium tracking-[-0.02em] text-bone">
              {SITE.shortName}
              <span className="hidden text-mute sm:inline"> Technologies</span>
            </span>
          </>
        }
        brandHref="#top"
        links={[
          { label: 'What we build', href: '#build' },
          { label: 'Palli', href: '#product' },
          { label: 'Nuvara', href: '#nuvara' },
          { label: 'How we build', href: '#philosophy' },
          { label: 'Contact', href: '#contact' },
        ]}
        cta={
          <MagneticButton href={SITE.palliPath} target="_blank" rel="noopener" variant="ghost" className="!px-5 !py-2.5 !text-[0.82rem]">
            Explore Palli
            <Arrow diagonal className="!h-3.5 !w-3.5" />
          </MagneticButton>
        }
      />
      <main className="relative z-10">
        <Hero />
        <WhatWeBuild />
        <ProductPortal product={PRODUCT} />
        <ProductPortal product={NUVARA} />
        <Philosophy />
        <Vision />
      </main>
    </div>
  )
}
