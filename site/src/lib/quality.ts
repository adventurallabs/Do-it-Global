/**
 * One-time device assessment. Everything expensive (particle counts,
 * pixel ratio, optional passes) reads from here instead of guessing.
 */
export type Tier = 'high' | 'mid' | 'low'

type Nav = Navigator & { deviceMemory?: number }

function detect() {
  if (typeof window === 'undefined') {
    return { tier: 'mid' as Tier, mobile: false, coarse: false, reduced: false, dpr: [1, 1.5] as [number, number], particles: 0.5 }
  }
  const w = window.innerWidth
  const coarse = window.matchMedia('(pointer: coarse)').matches
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  const mem = (navigator as Nav).deviceMemory ?? 8
  const cores = navigator.hardwareConcurrency ?? 8
  const mobile = coarse && Math.min(w, window.innerHeight) < 820

  // Any touch device (tablets included) shares GPU memory with a browser
  // that must also raster a tall, animated page — never treat it as 'high'.
  let tier: Tier = 'high'
  if (coarse || mem <= 4 || cores <= 4) tier = 'mid'
  if ((mobile && (mem <= 3 || cores <= 4)) || w < 360) tier = 'low'

  const dpr: [number, number] = tier === 'high' ? [1, 1.75] : tier === 'mid' ? [1, coarse ? 1.25 : 1.5] : [1, 1]
  const particles = tier === 'high' ? 1 : tier === 'mid' ? 0.45 : 0.28
  return { tier, mobile, coarse, reduced, dpr, particles }
}

export const quality = detect()

export const scaleCount = (n: number) => Math.max(200, Math.round(n * quality.particles))
