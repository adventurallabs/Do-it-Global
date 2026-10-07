import { lazy, Suspense, useRef } from 'react'
import { Nav } from '../components/Nav'
import { Cursor } from '../components/Cursor'
import { MagneticButton } from '../components/MagneticButton'
import { useScrollDirector } from '../hooks/useScrollDirector'
import { useReducedMotion } from '../hooks/useReducedMotion'
import { useTapNavigation } from '../hooks/useTapNavigation'
import { NuvaraHero, NuvaraIntro, NuvaraConnection, NuvaraPhilosophy, NuvaraFinale } from '../sections/nuvara/Story'
import { FamiliesShowcase, TherapistsShowcase, CentreShowcase } from '../sections/nuvara/Showcases'
import { AttendanceFeature, ProgressFeature, AssessmentFeature, FeesFeature, RequestsFeature } from '../sections/nuvara/Features'
import { TrustFeature, NuvaraSetup } from '../sections/nuvara/Trust'
import { OwnCentreApp, OwnServer } from '../sections/nuvara/Custom'
import { SITE } from '../data/site'

const SceneCanvas = lazy(() => import('../components/SceneCanvas'))
const NuvaraScene = lazy(() => import('../three/nuvara/NuvaraScene'))

export function NuvaraPage() {
  const reduced = useReducedMotion()
  useScrollDirector(reduced)
  const main = useRef<HTMLElement>(null)
  useTapNavigation(main)

  return (
    <div className="grain">
      <a href="#your-app" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[80] focus:rounded-full focus:bg-bone focus:px-4 focus:py-2 focus:text-ink">
        Skip to content
      </a>
      <Suspense fallback={null}>
        <SceneCanvas background="#06051a" reduced={reduced} fov={38}>
          <NuvaraScene />
        </SceneCanvas>
      </Suspense>
      <div aria-hidden className="vignette pointer-events-none fixed inset-0 z-[1]" />
      <Cursor />
      <Nav
        brand={
          <>
            <img src="/brand/nuvara-mark.webp" alt="" width={27} height={30} className="h-[30px] w-auto" />
            <span className="text-[1.05rem] font-semibold tracking-[0.04em] text-bone">NUVARA</span>
            <span className="t-label hidden text-[0.58rem] sm:inline">by {SITE.shortName}</span>
          </>
        }
        brandHref="#top"
        links={[
          { label: 'Your app', href: '#your-app' },
          { label: 'Families', href: '#families' },
          { label: 'Therapists', href: '#therapists' },
          { label: 'The centre', href: '#centre' },
          { label: 'Features', href: '#features' },
          { label: 'Own server', href: '#server' },
        ]}
        cta={
          <MagneticButton href="#contact" variant="orange" className="!px-4 !py-2 !text-[0.78rem] sm:!px-5 sm:!py-2.5 sm:!text-[0.82rem]">
            Talk to us
          </MagneticButton>
        }
      />
      <main ref={main} className="relative z-10 touch-manipulation">
        <NuvaraHero />
        <NuvaraIntro />
        <OwnCentreApp />
        <FamiliesShowcase />
        <TherapistsShowcase />
        <CentreShowcase />
        <NuvaraConnection />
        <AttendanceFeature />
        <ProgressFeature />
        <AssessmentFeature />
        <FeesFeature />
        <RequestsFeature />
        <OwnServer />
        <TrustFeature />
        <NuvaraSetup />
        <NuvaraPhilosophy />
        <NuvaraFinale />
      </main>
    </div>
  )
}
