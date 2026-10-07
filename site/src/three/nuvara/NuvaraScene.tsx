import { useMemo, useRef } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import * as THREE from 'three'
import { Backdrop, type BackdropLook } from '../common/Backdrop'
import { Dust } from '../common/Dust'
import { EcosystemCore, makeCoreUniforms, useGlowTexture } from '../palli/EcosystemCore'
import { OrbitRing, makeRingUniforms } from '../palli/OrbitRing'
import { FlowParticles, makeFlowUniforms } from '../palli/FlowParticles'
import { RoleNetwork, type Role } from '../palli/RoleNetwork'
import { scroll } from '../../lib/scrollStore'
import { scaleCount } from '../../lib/quality'
import { blendColor, blendNumber, sectionWeights } from '../../lib/blend'
import { damp, remap } from '../../lib/math'

type V3 = [number, number, number]
const C = (h: string) => new THREE.Color(h)

/** Nuvara's colours, from the logo: the orange "u", its sky-blue dots, the navy wordmark. */
const ORANGE = '#EA501E'
const SKY = '#36A9E0'
const LILAC = '#8F98D8'
const WARM = '#F7B267'

export const NUVARA_ROLES: readonly Role[] = [
  { id: 'admin', label: 'The centre', app: 'Timetable · Fees', color: LILAC },
  { id: 'therapist', label: 'Therapists', app: 'Sessions · Reports', color: ORANGE },
  { id: 'parent', label: 'Families', app: 'Schedule · Progress', color: SKY },
  { id: 'child', label: 'Children', app: 'Every step forward', color: WARM },
]
/** Who exchanges light: the centre with families and therapists, therapists with families and children. */
const PAIRS: [number, number][] = [
  [0, 2],
  [1, 3],
  [1, 2],
  [0, 1],
]

/** Every chapter's look, blended by on-screen share so chapters dissolve into each other. */
const STAGES: Record<
  string,
  {
    cam: V3
    core: V3
    coreM?: V3
    scale: number
    scaleM?: number
    rings: number
    network: number
    ringMode?: number
    glow?: number
    bgA: string
    bgB: string
    posA: [number, number]
    posB: [number, number]
    intensity: number
    dust: string
  }
> = {
  hero: { cam: [0, 0, 9.5], core: [0, 1.05, 0], coreM: [0, 1.2, 0], scale: 0.78, rings: 1, network: 0, bgA: '#1d2386', bgB: '#3d1607', posA: [0.5, 0.58], posB: [0.12, 0.18], intensity: 1.1, dust: '#ffc9b0' },
  intro: { cam: [0, 0, 10.5], core: [3.6, 0.2, -1.5], coreM: [0, 2.8, -4], scale: 0.85, rings: 0.8, network: 0, bgA: '#181d74', bgB: '#0a2a42', posA: [0.72, 0.55], posB: [0.12, 0.3], intensity: 1, dust: '#c8ccf5' },
  'your-app': { cam: [0, 0, 11], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#3d1607', bgB: '#161b66', posA: [0.68, 0.55], posB: [0.15, 0.25], intensity: 1.15, dust: '#ffc9b0' },
  families: { cam: [0, 0, 11], core: [4.6, 1.8, -7], coreM: [0, 3.4, -9], scale: 0.5, rings: 0.4, network: 0, bgA: '#0b3555', bgB: '#191866', posA: [0.7, 0.62], posB: [0.18, 0.22], intensity: 1.25, dust: '#9fdcff' },
  therapists: { cam: [0, 0, 11], core: [-1.5, -4.2, -9], coreM: [0, 3.4, -9], scale: 0.45, rings: 0.4, network: 0, bgA: '#4a1a07', bgB: '#171858', posA: [0.32, 0.62], posB: [0.82, 0.2], intensity: 1.15, dust: '#ffc0a3' },
  centre: { cam: [0, 0, 11], core: [-1.5, -4.2, -9], coreM: [0, 3.4, -9], scale: 0.45, rings: 0.4, network: 0, bgA: '#1f2690', bgB: '#2a1240', posA: [0.32, 0.62], posB: [0.82, 0.2], intensity: 1.15, dust: '#c3c8f5' },
  connection: { cam: [0, 0, 13.5], core: [0, 0, 0], coreM: [0, 1.8, 0], scale: 0.75, scaleM: 0.5, rings: 0, network: 1, ringMode: 0, bgA: '#1a1f70', bgB: '#0e1a33', posA: [0.5, 0.5], posB: [0.5, 0.05], intensity: 1.1, dust: '#c8ccf5' },
  attendance: { cam: [0, 0, 11], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#0b3a26', bgB: '#121a48', posA: [0.62, 0.45], posB: [0.15, 0.8], intensity: 1, dust: '#a7f0c4' },
  'progress-story': { cam: [0, 0, 11], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#0d2758', bgB: '#1c1438', posA: [0.62, 0.5], posB: [0.2, 0.2], intensity: 1.05, dust: '#9fc8ff' },
  assessment: { cam: [0, 0, 11], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#3d1708', bgB: '#151b52', posA: [0.62, 0.5], posB: [0.18, 0.25], intensity: 1.05, dust: '#ffc6ad' },
  fees: { cam: [0, 0, 11], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#0d2d3e', bgB: '#1a1636', posA: [0.55, 0.5], posB: [0.15, 0.25], intensity: 1, dust: '#a6dcff' },
  requests: { cam: [0, 0, 11], core: [0, 0, -5], scale: 0.001, rings: 0.2, network: 0, bgA: '#2a1656', bgB: '#3a1a0c', posA: [0.62, 0.5], posB: [0.25, 0.5], intensity: 1.05, dust: '#d4c4ff' },
  server: { cam: [0, 0, 11], core: [0, -3.2, -9], scale: 0.001, rings: 0.2, network: 0, bgA: '#0a2c48', bgB: '#1a1f70', posA: [0.6, 0.45], posB: [0.2, 0.8], intensity: 1.1, dust: '#9fd4ff' },
  trust: { cam: [0, 0, 11], core: [0, -3.2, -9], scale: 0.001, rings: 0.2, network: 0, bgA: '#0a2c48', bgB: '#101a3e', posA: [0.6, 0.45], posB: [0.2, 0.8], intensity: 1.1, dust: '#9fd4ff' },
  setup: { cam: [0, 0, 11], core: [0, -3.2, -9], scale: 0.001, rings: 0.2, network: 0, bgA: '#1a1f62', bgB: '#0e1a33', posA: [0.5, 0.4], posB: [0.5, 0.9], intensity: 1, dust: '#c8ccf5' },
  philosophy: { cam: [0, 0, 13.5], core: [0, -0.7, 0], coreM: [0, 0.2, 0], scale: 0.8, rings: 0.15, network: 1, ringMode: 1, bgA: '#1d2386', bgB: '#0e1a33', posA: [0.5, 0.5], posB: [0.5, 0.95], intensity: 1.05, dust: '#c8ccf5' },
  finale: { cam: [0, 0, 9.5], core: [0, 1.6, 0], coreM: [0, 2.6, 0], scale: 0.85, scaleM: 0.45, rings: 1, network: 0.25, ringMode: 1, glow: 1.7, bgA: '#2a30a0', bgB: '#3d1607', posA: [0.5, 0.62], posB: [0.5, 0.05], intensity: 1.45, dust: '#ffd2bf' },
}
const IDS = Object.keys(STAGES)
const col = (k: 'bgA' | 'bgB' | 'dust') => IDS.map((id) => C(STAGES[id][k]))
const num = (f: (s: (typeof STAGES)[string]) => number) => IDS.map((id) => f(STAGES[id]))
const TABLE = {
  camX: num((s) => s.cam[0]), camY: num((s) => s.cam[1]), camZ: num((s) => s.cam[2]),
  coreX: num((s) => s.core[0]), coreY: num((s) => s.core[1]), coreZ: num((s) => s.core[2]),
  coreMX: num((s) => (s.coreM ?? s.core)[0]), coreMY: num((s) => (s.coreM ?? s.core)[1]), coreMZ: num((s) => (s.coreM ?? s.core)[2]),
  scale: num((s) => s.scale), scaleM: num((s) => s.scaleM ?? s.scale * 0.8), rings: num((s) => s.rings), network: num((s) => s.network),
  ringMode: num((s) => s.ringMode ?? 0), ringModeW: num((s) => (s.network > 0 ? 1 : 0)),
  glow: num((s) => s.glow ?? 1), intensity: num((s) => s.intensity),
  pAx: num((s) => s.posA[0]), pAy: num((s) => s.posA[1]), pBx: num((s) => s.posB[0]), pBy: num((s) => s.posB[1]),
  bgA: col('bgA'), bgB: col('bgB'), dust: col('dust'),
}

/** Three orbits around the core: the centre, its therapists and the families. */
const RINGS = [
  { r: 2.45, rot: [1.2, 0.42, 0] as V3, a: ORANGE, b: '#ff9a6e', speed: 0.05, sat: 0.22, phase: 2.4 },
  { r: 3.15, rot: [1.05, -0.5, 0] as V3, a: SKY, b: '#8fd3f5', speed: -0.04, sat: -0.18, phase: -0.6 },
  { r: 2.8, rot: [1.45, 0.05, 0.6] as V3, a: LILAC, b: '#c3c8f5', speed: 0.03, sat: 0.14, phase: 4.2 },
]

export default function NuvaraScene() {
  const camera = useThree((s) => s.camera)
  const size = useThree((s) => s.size)
  const w = useMemo(() => new Array(IDS.length).fill(0), [])

  // A navy body (the wordmark's #010039 into indigo) with a sky rim, so the orange mark reads in front of it.
  const coreUniforms = useMemo(() => makeCoreUniforms({ rim: '#8fd0f2', deep: '#03022e', mid: '#2a31a8' }), [])
  const markOpacity = useRef(1)
  const coreGroup = useRef<THREE.Group>(null)
  const rings = useRef<(THREE.Group | null)[]>([])
  const sats = useRef<(THREE.Sprite | null)[]>([])
  const ringU = useMemo(() => RINGS.map((r) => makeRingUniforms(r.a, r.b)), [])
  // Light from therapists to families, and from the centre to families, through the core.
  const flows = useMemo(() => [makeFlowUniforms(ORANGE, '#ffd7c4', SKY), makeFlowUniforms(LILAC, '#e6e8ff', SKY)], [])
  const satPos = useMemo(() => RINGS.map(() => new THREE.Vector3()), [])
  const glow = useGlowTexture()

  const rolePositions = useMemo(() => Array.from({ length: 4 }, () => new THREE.Vector3()), [])
  const netOpacity = useRef(0)
  const labelOpacity = useRef(0)

  const look = useRef<BackdropLook>({ base: C('#06051a'), a: TABLE.bgA[0].clone(), b: TABLE.bgB[0].clone(), posA: [0.5, 0.58], posB: [0.12, 0.18], intensity: 1.1 })
  const dust = useRef(TABLE.dust[0].clone())
  const st = useRef({ cam: new THREE.Vector3(0, 0, 9.5), core: new THREE.Vector3(0, 0.35, 0), scale: 1, rings: 1, network: 0, ringMode: 0, glow: 1 })
  const tmp = useMemo(() => new THREE.Vector3(), [])

  useFrame((s, dt) => {
    dt = Math.min(dt, 0.05)
    const t = s.clock.elapsedTime
    const mobile = size.width < 768 || size.width / size.height < 0.85
    if (!sectionWeights(IDS, w)) {
      w.fill(0)
      w[0] = 1
    }
    const S = st.current
    const B = (k: keyof typeof TABLE) => blendNumber(TABLE[k] as number[], w)
    const lam = 3.2

    tmp.set(B('camX'), B('camY'), B('camZ'))
    S.cam.x = damp(S.cam.x, tmp.x, lam, dt)
    S.cam.y = damp(S.cam.y, tmp.y, lam * 0.8, dt)
    S.cam.z = damp(S.cam.z, tmp.z, lam, dt)
    if (mobile) tmp.set(B('coreMX'), B('coreMY'), B('coreMZ'))
    else tmp.set(B('coreX'), B('coreY'), B('coreZ'))
    S.core.lerp(tmp, 1 - Math.exp(-2.6 * dt))
    S.scale = damp(S.scale, mobile ? B('scaleM') : B('scale'), 2.6, dt)
    S.rings = damp(S.rings, B('rings'), 3, dt)
    S.network = damp(S.network, B('network'), 3, dt)
    const modeW = B('ringModeW')
    S.ringMode = damp(S.ringMode, modeW > 0.001 ? B('ringMode') / modeW : S.ringMode, 3, dt)
    S.glow = damp(S.glow, B('glow'), 2, dt)

    const px = scroll.pointer.sx
    const py = scroll.pointer.sy
    camera.position.set(S.cam.x + px * 0.45, S.cam.y + py * 0.3, S.cam.z)
    camera.lookAt(0, 0, 0)

    const g = coreGroup.current
    if (g) {
      g.position.copy(S.core)
      g.position.y += Math.sin(t * 0.6) * 0.06
      g.scale.setScalar(Math.max(0.0001, S.scale))
      g.rotation.y = px * 0.25
      g.rotation.x = -py * 0.15
      g.visible = S.scale > 0.01
    }
    coreUniforms.uTime.value = t
    coreUniforms.uGlow.value = S.glow
    markOpacity.current = Math.min(1, S.scale * 1.4)

    const rOp = S.rings
    RINGS.forEach((r, i) => {
      const u = ringU[i]
      u.uOpacity.value = rOp
      u.uTime.value = t
      u.uPR.value = s.gl.getPixelRatio()
      const ring = rings.current[i]
      if (ring) ring.rotation.z = t * r.speed
      placeSatellite(sats.current[i], ring, r.r, t * r.sat + r.phase, satPos[i], rOp)
    })
    flows.forEach((u, i) => {
      u.uA.value.copy(satPos[i === 0 ? 0 : 2])
      u.uB.value.copy(satPos[1])
      u.uC.value.copy(S.core)
      u.uTime.value = t
      u.uOpacity.value = rOp
      u.uPR.value = s.gl.getPixelRatio()
    })

    // Role network: the centre and therapists above, families and children below → a ring for the finale.
    const spread = mobile ? 0.4 : 1
    const spreadY = mobile ? 0.5 : 1
    const mode = S.ringMode
    for (let i = 0; i < 4; i++) {
      const cx = (i % 2 === 0 ? -3.4 : 3.4) * spread
      const cy = (i < 2 ? 2.3 : -2.3) * spreadY
      const ang = t * 0.12 + (i * Math.PI) / 2 + Math.PI / 4
      const rx = Math.cos(ang) * 3.6 * spread
      const ry = Math.sin(ang) * 1.9 * (mobile ? 0.65 : 1)
      const rz = Math.sin(ang) * 1.2
      rolePositions[i].set(cx + (rx - cx) * mode + S.core.x, cy + (ry - cy) * mode + S.core.y, rz * mode + S.core.z)
    }
    netOpacity.current = S.network
    labelOpacity.current = mobile ? 0 : remap(S.network, 0.6, 0.95)

    const l = look.current
    blendColor(TABLE.bgA, w, l.a)
    blendColor(TABLE.bgB, w, l.b)
    l.posA[0] = B('pAx')
    l.posA[1] = B('pAy')
    l.posB[0] = B('pBx')
    l.posB[1] = B('pBy')
    l.intensity = B('intensity')
    blendColor(TABLE.dust, w, dust.current)
  })

  const ringCount = scaleCount(2200)
  return (
    <>
      <Backdrop look={look} />
      <Dust count={1800} spread={[34, 70, 30]} center={[0, -14, -6]} color={dust} />
      <group ref={coreGroup}>
        <EcosystemCore uniforms={coreUniforms} markOpacity={markOpacity} mark="/brand/nuvara-mark.webp" markSize={[1.04, 1.16]} halo="#2b34c0" />
        {RINGS.map((r, i) => (
          <group key={i} ref={(el) => void (rings.current[i] = el)} rotation={r.rot}>
            <OrbitRing count={ringCount} radius={r.r} uniforms={ringU[i]} />
          </group>
        ))}
      </group>
      {RINGS.map((r, i) => (
        <sprite key={i} ref={(el) => void (sats.current[i] = el)} scale={[0.9, 0.9, 1]}>
          <spriteMaterial map={glow} color={r.a} transparent depthWrite={false} blending={THREE.AdditiveBlending} />
        </sprite>
      ))}
      {flows.map((u, i) => (
        <FlowParticles key={i} count={scaleCount(i ? 380 : 620)} uniforms={u} />
      ))}
      <RoleNetwork positions={rolePositions} opacity={netOpacity} labels={labelOpacity} roles={NUVARA_ROLES} pairs={PAIRS} via="#ffd7c4" />
    </>
  )
}

/** Put a satellite on a (rotated) ring and report its world position. */
function placeSatellite(sprite: THREE.Sprite | null, ring: THREE.Group | null, r: number, a: number, out: THREE.Vector3, opacity: number) {
  if (!ring) return
  out.set(Math.cos(a) * r, Math.sin(a) * r, 0)
  ring.localToWorld(out)
  if (sprite) {
    sprite.position.copy(out)
    ;(sprite.material as THREE.SpriteMaterial).opacity = opacity
    sprite.visible = opacity > 0.01
  }
}
