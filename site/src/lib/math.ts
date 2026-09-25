export const clamp = (v: number, a = 0, b = 1) => Math.min(b, Math.max(a, v))
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t
export const remap = (v: number, a: number, b: number) => clamp((v - a) / (b - a))
export const smooth = (v: number) => v * v * (3 - 2 * v)
/** 0 → 1 → 0 window over [a, b] with soft edges of width e. */
export const band = (v: number, a: number, b: number, e = 0.08) =>
  smooth(remap(v, a - e, a + e)) * (1 - smooth(remap(v, b - e, b + e)))
/** Frame-rate independent exponential damping. */
export const damp = (a: number, b: number, lambda: number, dt: number) => lerp(a, b, 1 - Math.exp(-lambda * dt))
