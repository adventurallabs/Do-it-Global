import { Suspense, useEffect, useRef, useState, type ReactNode } from 'react'
import { Canvas } from '@react-three/fiber'
import { PerformanceMonitor } from '@react-three/drei'
import { quality } from '../lib/quality'

type Props = {
  children: ReactNode
  background: string
  reduced: boolean
  fov?: number
}

/**
 * The fixed WebGL layer behind a page. One canvas per page; scenes inside
 * read scroll state from the store, so this component never re-renders on
 * scroll. DPR drops a step if the frame rate does.
 *
 * Mobile robustness:
 * - The layer is sized to the *large* viewport (100lvh), so the browser
 *   toolbar sliding in and out while scrolling never resizes (and clears)
 *   the drawing buffer.
 * - The wrapper paints the page colour itself, so a lost or not-yet-drawn
 *   context shows the dark backdrop, never a blank page.
 * - A lost context (common when a phone runs short of GPU memory) is
 *   restored by three.js; until then the canvas is hidden.
 */
export default function SceneCanvas({ children, background, reduced, fov = 35 }: Props) {
  const [dpr, setDpr] = useState<number>(Math.min(window.devicePixelRatio, quality.dpr[1]))
  const [ready, setReady] = useState(false)
  const [lost, setLost] = useState(false)
  const wrap = useRef<HTMLDivElement>(null)
  const cleanup = useRef<(() => void) | null>(null)

  // Reduced motion: the scene is a single still frame, so it belongs to the
  // opening screen only and fades away as the page scrolls on.
  useEffect(() => {
    if (!reduced) return
    const onScroll = () => {
      if (wrap.current) wrap.current.style.filter = `opacity(${Math.max(0, 1 - window.scrollY / (window.innerHeight * 0.9))})`
    }
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [reduced])

  useEffect(() => () => cleanup.current?.(), [])

  return (
    <div
      ref={wrap}
      aria-hidden
      className="pointer-events-none fixed left-0 top-0 z-0 w-full scene-layer"
      style={{ background }}
    >
      <div className="absolute inset-0 transition-opacity duration-[1800ms] ease-[var(--ease-out-expo)]" style={{ opacity: ready && !lost ? 1 : 0 }}>
        <Canvas
          dpr={dpr}
          camera={{ fov, position: [0, 0, 12], near: 0.1, far: 220 }}
          gl={{ antialias: quality.tier === 'high', powerPreference: quality.coarse ? 'default' : 'high-performance', alpha: false, stencil: false }}
          frameloop={reduced ? 'demand' : 'always'}
          // A fixed canvas never moves, so don't re-measure it on every scroll.
          resize={{ scroll: false, debounce: { scroll: 0, resize: 150 } }}
          onCreated={({ gl }) => {
            const canvas = gl.domElement
            const onLost = () => setLost(true)
            const onRestored = () => setLost(false)
            canvas.addEventListener('webglcontextlost', onLost)
            canvas.addEventListener('webglcontextrestored', onRestored)
            cleanup.current = () => {
              canvas.removeEventListener('webglcontextlost', onLost)
              canvas.removeEventListener('webglcontextrestored', onRestored)
            }
            requestAnimationFrame(() => setReady(true))
          }}
        >
          <color attach="background" args={[background]} />
          <PerformanceMonitor
            onDecline={() => setDpr((d) => Math.max(1, d - 0.35))}
            onIncline={() => setDpr((d) => Math.min(quality.dpr[1], d + 0.2))}
          />
          <Suspense fallback={null}>{children}</Suspense>
        </Canvas>
      </div>
    </div>
  )
}
