import { forwardRef, useRef, type CSSProperties, type ReactNode } from 'react'
import { useFitScale } from '../hooks/useFitScale'
import { quality } from '../lib/quality'

type Kind = 'phone' | 'tablet'

/** Native sizes in CSS px. Screens are laid out at real device points. */
export const DEVICE = {
  phone: { screenW: 390, screenH: 844, bezel: 13, radius: 60, screenRadius: 48 },
  tablet: { screenW: 1180, screenH: 820, bezel: 22, radius: 44, screenRadius: 24 },
} as const

type Props = {
  kind?: Kind
  children: ReactNode
  className?: string
  style?: CSSProperties
  /** Screen background while content crossfades. */
  screenBg?: string
  label?: string
}

/**
 * A device rendered in CSS so the UI inside stays pin-sharp at any size and
 * can be tilted in 3D by GSAP. The outer element fills its box; the device
 * inside is scaled to fit (contain).
 */
export const DeviceFrame = forwardRef<HTMLDivElement, Props>(function DeviceFrame(
  { kind = 'phone', children, className = '', style, screenBg = '#F7FBFF', label },
  ref,
) {
  const box = useRef<HTMLDivElement>(null)
  const d = DEVICE[kind]
  const W = d.screenW + d.bezel * 2
  const H = d.screenH + d.bezel * 2
  const scale = useFitScale(box, W, H)

  return (
    <div ref={box} className={`relative flex items-center justify-center ${className}`} style={style}>
      <div ref={ref} className="device-3d relative shrink-0" style={{ width: W * scale, height: H * scale }} role="img" aria-label={label}>
        <div className="absolute left-0 top-0 origin-top-left" style={{ width: W, height: H, transform: `scale(${scale})` }}>
          {/* Contact + ambient shadow */}
          <div
            aria-hidden
            className="absolute -inset-x-[6%] -bottom-[7%] h-[14%]"
            // Depth only matters when the device tilts in 3D. Touch devices keep
            // it flat, where this would just force a GPU layer per device.
            style={{ transform: quality.coarse ? undefined : 'translateZ(-60px)', background: 'radial-gradient(closest-side, rgba(0,0,0,.7), rgba(0,0,0,.35) 55%, transparent)' }}
          />
          {/* Chassis */}
          <div
            className="absolute inset-0"
            style={{
              borderRadius: d.radius,
              background: 'linear-gradient(145deg,#4a4a52 0%,#1d1d22 18%,#2c2c33 50%,#141418 82%,#3a3a42 100%)',
              boxShadow:
                '0 60px 120px -30px rgba(0,0,0,.85), 0 30px 60px -20px rgba(0,0,0,.6), inset 0 0 0 1.5px rgba(255,255,255,.14), inset 0 2px 1px rgba(255,255,255,.18)',
            }}
          />
          {/* Inner black bezel */}
          <div className="absolute bg-black" style={{ inset: 4, borderRadius: d.radius - 4 }} />
          {kind === 'phone' && (
            <>
              <span aria-hidden className="absolute -left-[3px] top-[170px] h-[64px] w-[4px] rounded-l bg-[#2a2a30]" />
              <span aria-hidden className="absolute -left-[3px] top-[250px] h-[64px] w-[4px] rounded-l bg-[#2a2a30]" />
              <span aria-hidden className="absolute -right-[3px] top-[210px] h-[96px] w-[4px] rounded-r bg-[#2a2a30]" />
            </>
          )}
          {/* Screen */}
          <div
            className="absolute overflow-hidden"
            style={{ left: d.bezel, top: d.bezel, width: d.screenW, height: d.screenH, borderRadius: d.screenRadius, background: screenBg }}
          >
            {children}
            {kind === 'phone' && (
              <div aria-hidden className="absolute left-1/2 top-[11px] z-50 h-[34px] w-[120px] -translate-x-1/2 rounded-full bg-black" />
            )}
            {/* Glass sheen. A plain translucent gradient moved by transform
                (--glare is driven by the scroll timeline): no blend mode, so the
                screen never needs an offscreen compositing pass. */}
            <div aria-hidden className="pointer-events-none absolute inset-0 z-50 overflow-hidden">
              <div
                className="absolute inset-y-0 left-0 w-[250%]"
                style={{
                  background: 'linear-gradient(115deg, transparent 35%, rgba(255,255,255,.09) 47%, rgba(255,255,255,.02) 55%, transparent 65%)',
                  transform: 'translateX(calc(var(--glare, 0.5) * -60%))',
                }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  )
})
