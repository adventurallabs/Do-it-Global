import { useLayoutEffect, useRef } from 'react'
import { gsap } from '../../animations/gsap'
import { SectionLabel } from '../../components/Primitives'
import { RevealText } from '../../components/RevealText'
import { Arrow } from '../../components/MagneticButton'
import { useSection } from '../../hooks/useSection'
import { useReducedMotion } from '../../hooks/useReducedMotion'
import { useFinePointer } from '../../hooks/useMediaQuery'
import { type Product } from '../../data/company'

/**
 * A product "portal": a card built as a stack of depth layers. It tilts
 * toward the pointer, its layers separate on hover, and it swings into
 * place as the section scrolls in. The whole object is one link that
 * opens the product page in a new tab.
 */
export function ProductPortal({ product }: { product: Product }) {
  const sectionRef = useSection<HTMLElement>(product.id)
  const stage = useRef<HTMLDivElement>(null)
  const scrollWrap = useRef<HTMLDivElement>(null)
  const tilt = useRef<HTMLAnchorElement>(null)
  const reduced = useReducedMotion()
  const fine = useFinePointer()

  useLayoutEffect(() => {
    const st = stage.current
    const wrap = scrollWrap.current
    if (!st || !wrap || reduced) return
    const ctx = gsap.context(() => {
      const tl = gsap.timeline({
        scrollTrigger: { trigger: st.parentElement, start: 'top bottom', end: 'bottom top', scrub: 0.8 },
        defaults: { ease: 'none' },
      })
      tl.fromTo(wrap, { rotateX: 32, y: '22vh', scale: 0.84, opacity: 0 }, { rotateX: 0, y: 0, scale: 1, opacity: 1, duration: 0.34, ease: 'power2.out' })
        .to(wrap, { duration: 0.36 })
        .to(wrap, { rotateX: -14, y: '-16vh', scale: 0.94, opacity: 0.2, duration: 0.3, ease: 'power1.in' })
    }, st)
    return () => ctx.revert()
  }, [reduced])

  useLayoutEffect(() => {
    const st = stage.current
    const card = tilt.current
    if (!st || !card || !fine || reduced) return
    const rx = gsap.quickTo(card, 'rotateX', { duration: 1.1, ease: 'expo.out' })
    const ry = gsap.quickTo(card, 'rotateY', { duration: 1.1, ease: 'expo.out' })
    const move = (e: PointerEvent) => {
      const r = card.getBoundingClientRect()
      const x = (e.clientX - (r.left + r.width / 2)) / (window.innerWidth / 2)
      const y = (e.clientY - (r.top + r.height / 2)) / (window.innerHeight / 2)
      ry(x * 11)
      rx(-y * 9)
      card.style.setProperty('--mx', `${((e.clientX - r.left) / r.width) * 100}%`)
      card.style.setProperty('--my', `${((e.clientY - r.top) / r.height) * 100}%`)
    }
    const leave = () => {
      rx(0)
      ry(0)
    }
    st.addEventListener('pointermove', move)
    st.addEventListener('pointerleave', leave)
    return () => {
      st.removeEventListener('pointermove', move)
      st.removeEventListener('pointerleave', leave)
    }
  }, [fine, reduced])

  const [first, second] = product.apps

  return (
    <section ref={sectionRef} id={product.id} className="relative h-[210svh]">
      <div ref={stage} className="sticky-stage">
        <div className="pointer-events-none absolute inset-x-0 top-0 z-10 mx-auto flex max-w-[1600px] items-start justify-between px-5 pt-24 sm:px-8 md:px-12 md:pt-28">
          <div>
            <SectionLabel index={product.index}>{product.label}</SectionLabel>
            <RevealText text={`Meet ${product.name}.`} as="h2" className="t-h2 mt-5 text-bone" />
          </div>
          <p className="t-label hidden max-w-[16rem] text-right leading-relaxed md:block">{product.note}</p>
        </div>

        <div className="flex h-full items-center justify-center px-5 pt-16" style={{ perspective: '1600px' }}>
          <div ref={scrollWrap} className="will-change-transform" style={{ transformStyle: 'preserve-3d' }}>
            <a
              ref={tilt}
              href={product.path}
              target="_blank"
              rel="noopener"
              data-cursor="portal"
              aria-label={`Explore ${product.name} — opens the ${product.name} product page in a new tab`}
              className="portal group relative block h-[min(38rem,68svh)] w-[min(33rem,88vw)] rounded-[36px]"
            >
              {/* Rotating light on the rim */}
              <span aria-hidden className={`portal-rim absolute -inset-px rounded-[37px] ${product.rim === 'nuvara' ? 'portal-rim-nuvara' : ''}`} />
              {/* Body */}
              <span
                aria-hidden
                className="absolute inset-0 rounded-[36px] border border-white/10"
                style={{
                  background:
                    `radial-gradient(120% 70% at 50% -10%, rgba(${product.glow},.42), transparent 62%), radial-gradient(60% 50% at var(--mx,50%) var(--my,30%), rgba(${product.tint},.14), transparent 70%), linear-gradient(180deg,#14111c,#0b0a10 70%)`,
                  boxShadow: `0 80px 140px -40px rgba(0,0,0,.9), 0 0 120px -30px rgba(${product.glow},.45), inset 0 1px 0 rgba(255,255,255,.12)`,
                }}
              />

              {/* Layer 1 — identity */}
              <span className="portal-layer absolute inset-x-8 top-8 flex items-start justify-between md:inset-x-10 md:top-10" style={{ '--z': '34px' } as React.CSSProperties}>
                <span className="flex items-center gap-3">
                  <img src={product.mark.src} alt="" width={product.mark.w} height={product.mark.h} className="h-10 w-auto" />
                  <span className="text-[1.6rem] font-semibold tracking-[0.02em] text-white">{product.wordmark}</span>
                </span>
                <span className="t-label mt-2 text-[0.6rem]" style={{ color: `rgb(${product.tint})` }}>
                  {product.kicker}
                </span>
              </span>

              <span
                className="portal-layer absolute inset-x-8 top-[5.4rem] block max-w-[15.5rem] text-[1.3rem] leading-[1.2] tracking-[-0.025em] text-bone/90 md:inset-x-10 md:top-[6.2rem] md:max-w-[17rem] md:text-[1.5rem]"
                style={{ '--z': '44px' } as React.CSSProperties}
              >
                {product.tagline}
              </span>

              {/* Layer 2 — the two apps and the line between them */}
              <svg aria-hidden className="portal-layer absolute inset-0 h-full w-full" viewBox="0 0 100 100" preserveAspectRatio="none" style={{ '--z': '58px' } as React.CSSProperties}>
                <path d="M 70 58 C 66 66, 40 58, 32 66" fill="none" stroke={`url(#pl-${product.id})`} strokeWidth="0.35" vectorEffect="non-scaling-stroke" strokeDasharray="2 3" />
                <defs>
                  <linearGradient id={`pl-${product.id}`} x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0" stopColor={second.accent} />
                    <stop offset="0.5" stopColor={`rgb(${product.tint})`} />
                    <stop offset="1" stopColor={first.accent} />
                  </linearGradient>
                </defs>
              </svg>

              <AppChip app={second} className="right-5 top-[42%] md:right-7" z={96} />
              <AppChip app={first} className="left-5 top-[61%] md:left-7" z={82} />

              {/* Layer 3 — call to action */}
              <span className="portal-layer absolute inset-x-8 bottom-8 flex items-end justify-between md:inset-x-10 md:bottom-10" style={{ '--z': '40px' } as React.CSSProperties}>
                <span>
                  <span className="block text-[0.95rem] font-medium uppercase tracking-[0.14em] text-white">Explore {product.name}</span>
                  <span className="t-label mt-2 block text-[0.6rem]">Opens in a new tab</span>
                </span>
                <span className="flex h-14 w-14 items-center justify-center rounded-full bg-white text-ink transition-transform duration-700 ease-[var(--ease-out-expo)] group-hover:scale-110">
                  <Arrow diagonal className="h-5 w-5" />
                </span>
              </span>
            </a>
          </div>
        </div>
      </div>
    </section>
  )
}

function AppChip({ app, className, z }: { app: Product['apps'][number]; className: string; z: number }) {
  return (
    <span
      className={`portal-layer absolute block w-[min(17rem,74%)] rounded-2xl border border-white/10 bg-[#17151f]/90 p-3.5 shadow-[0_30px_60px_-20px_rgba(0,0,0,.8)] ${className}`}
      style={{ '--z': `${z}px` } as React.CSSProperties}
    >
      <span className="flex items-center gap-3">
        <img src={app.icon} alt="" width={40} height={40} className="h-10 w-10 rounded-[11px]" loading="lazy" />
        <span className="min-w-0">
          <span className="block text-[0.95rem] font-medium tracking-[-0.01em] text-white">{app.name}</span>
          <span className="block text-[0.75rem] text-mute">{app.audience}</span>
        </span>
      </span>
      <span className="mt-3 flex gap-1.5 whitespace-nowrap">
        {app.features.map((f) => (
          <span key={f} className="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1 text-[0.68rem] text-bone/80">
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: app.accent }} />
            {f}
          </span>
        ))}
      </span>
    </span>
  )
}
