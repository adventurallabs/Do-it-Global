/**
 * Four shapes for the company field, one per chapter of the story:
 *   0 seed   — a living sphere: an idea
 *   1 stack  — layered plates: the systems it becomes
 *   2 portal — a ring that frames the product
 *   3 globe  — latitudes and meridians: the world it serves
 * Each is shuffled independently so morphs read as flows, not sweeps.
 */

const gauss = () => {
  let u = 0
  let v = 0
  while (u === 0) u = Math.random()
  while (v === 0) v = Math.random()
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v)
}

function shuffleInto(src: number[][], n: number): Float32Array {
  for (let i = src.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[src[i], src[j]] = [src[j], src[i]]
  }
  const out = new Float32Array(n * 3)
  for (let i = 0; i < n; i++) {
    const p = src[i % src.length]
    out[i * 3] = p[0]
    out[i * 3 + 1] = p[1]
    out[i * 3 + 2] = p[2]
  }
  return out
}

function fib(i: number, n: number): [number, number, number] {
  const y = 1 - (i / (n - 1)) * 2
  const r = Math.sqrt(1 - y * y)
  const th = i * 2.399963229728653
  return [Math.cos(th) * r, y, Math.sin(th) * r]
}

export function seed(n: number) {
  const pts: number[][] = []
  for (let i = 0; i < n; i++) {
    const [x, y, z] = fib(i, n)
    const inner = Math.random() < 0.14
    const r = inner ? Math.pow(Math.random(), 0.6) * 1.8 : 2.05 + gauss() * 0.035
    pts.push([x * r, y * r, z * r])
  }
  return shuffleInto(pts, n)
}

export function stack(n: number) {
  const pts: number[][] = []
  const levels = [-1.35, -0.45, 0.45, 1.35]
  const plateShare = 0.82
  const perPlate = Math.floor((n * plateShare) / levels.length)
  const g = Math.max(8, Math.floor(Math.sqrt(perPlate)))
  const size = 3.3
  const tilt = 0.52
  const c = Math.cos(tilt)
  const s = Math.sin(tilt)
  const push = (x: number, y: number, z: number) => pts.push([x, c * y - s * z, s * y + c * z])
  for (const [li, ly] of levels.entries()) {
    const inset = li === 3 ? 0.78 : li === 0 ? 1 : 0.92
    for (let i = 0; i < perPlate; i++) {
      const gx = i % g
      const gz = Math.floor(i / g) % g
      const x = (gx / (g - 1) - 0.5) * size * inset
      const z = (gz / (g - 1) - 0.5) * size * inset
      push(x + gauss() * 0.004, ly, z + gauss() * 0.004)
    }
  }
  const rest = n - perPlate * levels.length
  const h = size / 2
  const pillars: [number, number][] = [
    [-h * 0.92, -h * 0.92],
    [h * 0.92, -h * 0.92],
    [-h * 0.92, h * 0.92],
    [h * 0.92, h * 0.92],
    [0, 0],
  ]
  for (let i = 0; i < rest; i++) {
    const [px, pz] = pillars[i % pillars.length]
    const y = -1.35 + Math.random() * 2.7
    push(px + gauss() * 0.02, y, pz + gauss() * 0.02)
  }
  return shuffleInto(pts, n)
}

export function portal(n: number) {
  const pts: number[][] = []
  const R = 4.25
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2
    const halo = Math.random() < 0.28
    const rr = halo ? R + gauss() * 0.45 : R + gauss() * 0.07
    const z = halo ? gauss() * 0.3 : gauss() * 0.06
    pts.push([Math.cos(a) * rr, Math.sin(a) * rr, z])
  }
  return shuffleInto(pts, n)
}

export function globe(n: number) {
  const pts: number[][] = []
  const R = 2.45
  const lats: number[] = []
  for (let d = -75; d <= 75; d += 15) lats.push((d * Math.PI) / 180)
  const latShare = Math.floor(n * 0.64)
  const merShare = Math.floor(n * 0.28)
  const weights = lats.map((l) => Math.cos(l))
  const wsum = weights.reduce((a, b) => a + b, 0)
  lats.forEach((lat, i) => {
    const count = Math.floor((latShare * weights[i]) / wsum)
    for (let k = 0; k < count; k++) {
      const lon = (k / count) * Math.PI * 2
      pts.push([Math.cos(lat) * Math.cos(lon) * R, Math.sin(lat) * R, Math.cos(lat) * Math.sin(lon) * R])
    }
  })
  const meridians = 12
  for (let k = 0; k < merShare; k++) {
    const lon = ((k % meridians) / meridians) * Math.PI
    const t = Math.random() * Math.PI * 2
    pts.push([Math.cos(t) * Math.cos(lon) * R, Math.sin(t) * R, Math.cos(t) * Math.sin(lon) * R])
  }
  while (pts.length < n) {
    const [x, y, z] = fib(Math.floor(Math.random() * 5000), 5000)
    const r = R * (1 + gauss() * 0.012)
    pts.push([x * r, y * r, z * r])
  }
  return shuffleInto(pts, n)
}
