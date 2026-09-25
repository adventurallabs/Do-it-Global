import { lazy, Suspense } from 'react'
import { Nav } from '../components/Nav'
import { Cursor } from '../components/Cursor'
import { MagneticButton } from '../components/MagneticButton'
import { useScrollDirector } from '../hooks/useScrollDirector'
import { useReducedMotion } from '../hooks/useReducedMotion'
import { PalliHero, EcosystemIntro, Connection, Philosophy, Finale } from '../sections/palli/Story'
import { ConnectShowcase, CoreShowcase } from '../sections/palli/Showcases'
import { AttendanceFeature, ProgressFeature, CommunicationFeature, FeesFeature, BusFeature } from '../sections/palli/Features'
import { OwnApp, Modules, PrivateCloud, Setup } from '../sections/palli/Custom'
import { SITE } from '../data/site'

const SceneCanvas = lazy(() => import('../components/SceneCanvas'))
const PalliScene = lazy(() => import('../three/palli/PalliScene'))

export function PalliPage() {
  const reduced = useReducedMotion()
  useScrollDirector(reduced)

  return (
    <div className="grain">
      <a href="#your-app" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[80] focus:rounded-full focus:bg-bone focus:px-4 focus:py-2 focus:text-ink">
        Skip to content
      </a>
      <Suspense fallback={null}>
        <SceneCanvas background="#07060b" reduced={reduced} fov={38}>
          <PalliScene />
        </SceneCanvas>
      </Suspense>
      <div aria-hidden className="vignette pointer-events-none fixed inset-0 z-[1]" />
      <Cursor />
      <Nav
        brand={
          <>
            <img src="/brand/palli-mark.webp" alt="" width={30} height={31} className="h-[30px] w-auto" />
            <span className="text-[1.05rem] font-semibold tracking-[0.04em] text-bone">PALLI</span>
            <span className="t-label hidden text-[0.58rem] sm:inline">by {SITE.shortName}</span>
          </>
        }
        brandHref="#top"
        links={[
          { label: 'Your app', href: '#your-app' },
          { label: 'PalliConnect', href: '#connect' },
          { label: 'PalliCore', href: '#core' },
          { label: 'Features', href: '#features' },
          { label: 'Private cloud', href: '#cloud' },
        ]}
        cta={
          <MagneticButton href="#contact" variant="violet" className="!px-4 !py-2 !text-[0.78rem] sm:!px-5 sm:!py-2.5 sm:!text-[0.82rem]">
            Talk to us
          </MagneticButton>
        }
      />
      <main className="relative z-10">
        <PalliHero />
        <EcosystemIntro />
        <OwnApp />
        <Modules />
        <ConnectShowcase />
        <CoreShowcase />
        <Connection />
        <AttendanceFeature />
        <ProgressFeature />
        <CommunicationFeature />
        <FeesFeature />
        <BusFeature />
        <PrivateCloud />
        <Setup />
        <Philosophy />
        <Finale />
      </main>
    </div>
  )
}
