import { useMemo, useRef } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import * as THREE from 'three'
import { Backdrop, type BackdropLook } from '../common/Backdrop'
import { Dust } from '../common/Dust'
import { EcosystemCore, makeCoreUniforms, useGlowTexture } from './EcosystemCore'
import { OrbitRing, makeRingUniforms } from './OrbitRing'
import { FlowParticles, makeFlowUniforms } from './FlowParticles'
import { RoleNetwork } from './RoleNetwork'
import { BusWorld } from './BusWorld'
import { scroll, section } from '../../lib/scrollStore'
import { scaleCount } from '../../lib/quality'
import { blendColor, blendNumber, sectionWeights } from '../../lib/blend'
import { damp, remap } from '../../lib/math'

type V3 = [number, number, number]
const C = (h: string) => new THREE.Color(h)
const BUS_Y = -30

/** Every chapter's look. Blended by on-screen share, so chapters dissolve into each other. */
const STAGES: Record<
  string,
  {
    cam: V3
    target: V3
    core: V3
    coreM?: V3
    scale: number
    /** Core scale on narrow screens (defaults to 0.8 × scale). */
    scaleM?: number
    rings: number
    network: number
    ringMode?: number
    bus?: number
    glow?: number
    bgA: string
    bgB: string
    posA: [number, number]
    posB: [number, number]
    intensity: number
    dust: string
  }
> = {
  hero: { cam: [0, 0, 9.5], target: [0, 0, 0], core: [0, 1.05, 0], coreM: [0, 1.2, 0], scale: 0.78, rings: 1, network: 0, bgA: '#2a1450', bgB: '#0b1830', posA: [0.5, 0.58], posB: [0.12, 0.18], intensity: 1.1, dust: '#cdb8ff' },
  intro: { cam: [0, 0, 10.5], target: [0, 0, 0], core: [3.6, 0.2, -1.5], coreM: [0, 2.8, -4], scale: 0.85, rings: 0.8, network: 0, bgA: '#241246', bgB: '#0b1830', posA: [0.72, 0.55], posB: [0.12, 0.3], intensity: 1, dust: '#cdb8ff' },
  ownapp: { cam: [0, 0, 11], target: [0, 0, 0], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#2a1458', bgB: '#10204a', posA: [0.68, 0.55], posB: [0.15, 0.25], intensity: 1.15, dust: '#d4c4ff' },
  modules: { cam: [0, 0, 11], target: [0, 0, 0], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#0b2f22', bgB: '#1a1640', posA: [0.62, 0.5], posB: [0.18, 0.2], intensity: 1.05, dust: '#a7f0c4' },
  connect: { cam: [0, 0, 11], target: [0, 0, 0], core: [4.6, 1.8, -7], coreM: [0, 3.4, -9], scale: 0.5, rings: 0.4, network: 0, bgA: '#0d2a5c', bgB: '#0b2f22', posA: [0.7, 0.62], posB: [0.18, 0.22], intensity: 1.25, dust: '#9fd4ff' },
  core: { cam: [0, 0, 11], target: [0, 0, 0], core: [-1.5, -4.2, -9], coreM: [0, 3.4, -9], scale: 0.45, rings: 0.4, network: 0, bgA: '#3a2a10', bgB: '#1d1830', posA: [0.32, 0.62], posB: [0.82, 0.2], intensity: 1.15, dust: '#f0d9a0' },
  connection: { cam: [0, 0, 13.5], target: [0, 0, 0], core: [0, 0, 0], coreM: [0, 1.8, 0], scale: 0.75, scaleM: 0.5, rings: 0, network: 1, ringMode: 0, bgA: '#26134a', bgB: '#0e1a33', posA: [0.5, 0.5], posB: [0.5, 0.05], intensity: 1.1, dust: '#cdb8ff' },
  attendance: { cam: [0, 0, 11], target: [0, 0, 0], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#0b2a20', bgB: '#101a33', posA: [0.62, 0.45], posB: [0.15, 0.8], intensity: 1, dust: '#a7f0c4' },
  progress: { cam: [0, 0, 11], target: [0, 0, 0], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#0d2350', bgB: '#1c1438', posA: [0.62, 0.5], posB: [0.2, 0.2], intensity: 1.05, dust: '#9fc2ff' },
  communication: { cam: [0, 0, 11], target: [0, 0, 0], core: [0, 0, -5], scale: 0.001, rings: 0.2, network: 0, bgA: '#231544', bgB: '#2a200c', posA: [0.62, 0.5], posB: [0.25, 0.5], intensity: 1.05, dust: '#d4c4ff' },
  fees: { cam: [0, 0, 11], target: [0, 0, 0], core: [0, -3.2, -9], scale: 0.001, rings: 0.3, network: 0, bgA: '#0d2a3a', bgB: '#1a1433', posA: [0.55, 0.5], posB: [0.15, 0.25], intensity: 1, dust: '#a6dcff' },
  bus: { cam: [2.5, BUS_Y + 7.6, 7.4], target: [1.4, BUS_Y, -1.9], core: [0, 6, -20], scale: 0.001, rings: 0, network: 0, bus: 1, bgA: '#0a1a33', bgB: '#07231a', posA: [0.35, 0.7], posB: [0.7, 0.15], intensity: 1, dust: '#9fb8ff' },
  cloud: { cam: [0, 0, 11], target: [0, 0, 0], core: [0, -3.2, -9], scale: 0.001, rings: 0.2, network: 0, bgA: '#0a2a44', bgB: '#101a3a', posA: [0.6, 0.45], posB: [0.2, 0.8], intensity: 1.1, dust: '#9fd4ff' },
  setup: { cam: [0, 0, 11], target: [0, 0, 0], core: [0, -3.2, -9], scale: 0.001, rings: 0.2, network: 0, bgA: '#1e1446', bgB: '#0e1a33', posA: [0.5, 0.4], posB: [0.5, 0.9], intensity: 1, dust: '#cdb8ff' },
  philosophy: { cam: [0, 0, 13.5], target: [0, 0, 0], core: [0, -0.7, 0], coreM: [0, 0.2, 0], scale: 0.8, rings: 0.15, network: 1, ringMode: 1, bgA: '#2a1450', bgB: '#0e1a33', posA: [0.5, 0.5], posB: [0.5, 0.95], intensity: 1.05, dust: '#cdb8ff' },
  finale: { cam: [0, 0, 9.5], target: [0, 0, 0], core: [0, 1.6, 0], coreM: [0, 2.6, 0], scale: 0.85, scaleM: 0.45, rings: 1, network: 0.25, ringMode: 1, glow: 1.7, bgA: '#3b1a70', bgB: '#10183a', posA: [0.5, 0.62], posB: [0.5, 0.05], intensity: 1.45, dust: '#dccbff' },
}
const IDS = Object.keys(STAGES)
const col = (k: 'bgA' | 'bgB' | 'dust') => IDS.map((id) => C(STAGES[id][k]))
const num = (f: (s: (typeof STAGES)[string]) => number) => IDS.map((id) => f(STAGES[id]))
const TABLE = {
  camX: num((s) => s.cam[0]), camY: num((s) => s.cam[1]), camZ: num((s) => s.cam[2]),
  tgX: num((s) => s.target[0]), tgY: num((s) => s.target[1]), tgZ: num((s) => s.target[2]),
  coreX: num((s) => s.core[0]), coreY: num((s) => s.core[1]), coreZ: num((s) => s.core[2]),
  coreMX: num((s) => (s.coreM ?? s.core)[0]), coreMY: num((s) => (s.coreM ?? s.core)[1]), coreMZ: num((s) => (s.coreM ?? s.core)[2]),
  scale: num((s) => s.scale), scaleM: num((s) => s.scaleM ?? s.scale * 0.8), rings: num((s) => s.rings), network: num((s) => s.network),
  ringMode: num((s) => s.ringMode ?? 0), ringModeW: num((s) => (s.network > 0 ? 1 : 0)),
  bus: num((s) => s.bus ?? 0), glow: num((s) => s.glow ?? 1), intensity: num((s) => s.intensity),
  pAx: num((s) => s.posA[0]), pAy: num((s) => s.posA[1]), pBx: num((s) => s.posB[0]), pBy: num((s) => s.posB[1]),
  bgA: col('bgA'), bgB: col('bgB'), dust: col('dust'),
}

export default function PalliScene() {
  const camera = useThree((s) => s.camera)
  const size = useThree((s) => s.size)
  const w = useMemo(() => new Array(IDS.length).fill(0), [])

  const coreUniforms = useMemo(makeCoreUniforms, [])
  const markOpacity = useRef(1)
  const coreGroup = useRef<THREE.Group>(null)
  const ringCore = useRef<THREE.Group>(null)
  const ringConnect = useRef<THREE.Group>(null)
  const satCore = useRef<THREE.Sprite>(null)
  const satConnect = useRef<THREE.Sprite>(null)
  const coreRingU = useMemo(() => makeRingUniforms('#E2C275', '#C9A24A'), [])
  const connectRingU = useMemo(() => makeRingUniforms('#3EC6FF', '#2F6BFF'), [])
  const heroFlow = useMemo(() => makeFlowUniforms('#E2C275', '#c8a6ff', '#3EC6FF'), [])
  const glow = useGlowTexture()

  const rolePositions = useMemo(() => Array.from({ length: 4 }, () => new THREE.Vector3()), [])
  const netOpacity = useRef(0)
  const labelOpacity = useRef(0)
  const busProgress = useRef(0)
  const busOpacity = useRef(0)

  const look = useRef<BackdropLook>({ base: C('#07060b'), a: TABLE.bgA[0].clone(), b: TABLE.bgB[0].clone(), posA: [0.5, 0.58], posB: [0.12, 0.18], intensity: 1.1 })
  const dust = useRef(TABLE.dust[0].clone())

  const st = useRef({ cam: new THREE.Vector3(0, 0, 9.5), tgt: new THREE.Vector3(), core: new THREE.Vector3(0, 0.35, 0), scale: 1, rings: 1, network: 0, ringMode: 0, bus: 0, glow: 1 })
  const tmp = useMemo(() => ({ v: new THREE.Vector3(), a: new THREE.Vector3(), b: new THREE.Vector3() }), [])

  useFrame((s, dt) => {
    dt = Math.min(dt, 0.05)
    const t = s.clock.elapsedTime
    // Phones and portrait tablets share the stacked (narrow) layout.
    const mobile = size.width < 768 || size.width / size.height < 0.85
    if (!sectionWeights(IDS, w)) {
      w.fill(0)
      w[0] = 1
    }
    const S = st.current
    const B = (k: keyof typeof TABLE) => blendNumber(TABLE[k] as number[], w)
    const lam = 3.2

    tmp.v.set(B('camX'), B('camY'), B('camZ'))
    S.cam.x = damp(S.cam.x, tmp.v.x, lam, dt)
    S.cam.y = damp(S.cam.y, tmp.v.y, lam * 0.8, dt)
    S.cam.z = damp(S.cam.z, tmp.v.z, lam, dt)
    tmp.v.set(B('tgX'), B('tgY'), B('tgZ'))
    S.tgt.lerp(tmp.v, 1 - Math.exp(-lam * 0.8 * dt))
    if (mobile) tmp.v.set(B('coreMX'), B('coreMY'), B('coreMZ'))
    else tmp.v.set(B('coreX'), B('coreY'), B('coreZ'))
    S.core.lerp(tmp.v, 1 - Math.exp(-2.6 * dt))
    S.scale = damp(S.scale, mobile ? B('scaleM') : B('scale'), 2.6, dt)
    S.rings = damp(S.rings, B('rings'), 3, dt)
    S.network = damp(S.network, B('network'), 3, dt)
    const modeW = B('ringModeW')
    S.ringMode = damp(S.ringMode, modeW > 0.001 ? B('ringMode') / modeW : S.ringMode, 3, dt)
    S.bus = damp(S.bus, B('bus'), 4, dt)
    S.glow = damp(S.glow, B('glow'), 2, dt)

    // Camera: drift with the pointer, then look.
    const px = scroll.pointer.sx
    const py = scroll.pointer.sy
    camera.position.set(S.cam.x + px * 0.45, S.cam.y + py * 0.3, S.cam.z)
    camera.lookAt(S.tgt)

    // Core
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

    // App orbits and the light between them
    const rOp = S.rings
    coreRingU.uOpacity.value = connectRingU.uOpacity.value = rOp
    coreRingU.uTime.value = connectRingU.uTime.value = t
    coreRingU.uPR.value = connectRingU.uPR.value = s.gl.getPixelRatio()
    if (ringCore.current) ringCore.current.rotation.z = t * 0.05
    if (ringConnect.current) ringConnect.current.rotation.z = -t * 0.04
    placeSatellite(satCore.current, ringCore.current, 2.55, t * 0.22 + 2.4, tmp.a, rOp)
    placeSatellite(satConnect.current, ringConnect.current, 3.15, -t * 0.18 - 0.6, tmp.b, rOp)
    heroFlow.uA.value.copy(tmp.a)
    heroFlow.uB.value.copy(tmp.b)
    heroFlow.uC.value.copy(S.core)
    heroFlow.uTime.value = t
    heroFlow.uOpacity.value = rOp
    heroFlow.uPR.value = s.gl.getPixelRatio()

    // Role network: school side above, family side below → a ring for the finale.
    const spread = mobile ? 0.4 : 1
    // Narrow screens: squeeze the network into the band between heading and copy.
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
    // On narrow screens the copy already names every role; floating labels would sit on top of it.
    labelOpacity.current = mobile ? 0 : remap(S.network, 0.6, 0.95)

    // Bus world
    const bp = section('bus').pinned
    busProgress.current = damp(busProgress.current, remap(bp, 0.08, 0.88), 5, dt)
    busOpacity.current = S.bus

    // Atmosphere
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

  const ringCount = scaleCount(2600)
  return (
    <>
      <Backdrop look={look} />
      <Dust count={1800} spread={[34, 70, 30]} center={[0, -14, -6]} color={dust} />
      <group ref={coreGroup}>
        <EcosystemCore uniforms={coreUniforms} markOpacity={markOpacity} />
        <group ref={ringCore} rotation={[1.2, 0.42, 0]}>
          <OrbitRing count={ringCount} radius={2.55} uniforms={coreRingU} />
        </group>
        <group ref={ringConnect} rotation={[1.05, -0.5, 0]}>
          <OrbitRing count={ringCount} radius={3.15} uniforms={connectRingU} />
        </group>
      </group>
      <sprite ref={satCore} scale={[0.9, 0.9, 1]}>
        <spriteMaterial map={glow} color="#E2C275" transparent depthWrite={false} blending={THREE.AdditiveBlending} />
      </sprite>
      <sprite ref={satConnect} scale={[0.9, 0.9, 1]}>
        <spriteMaterial map={glow} color="#3EC6FF" transparent depthWrite={false} blending={THREE.AdditiveBlending} />
      </sprite>
      <FlowParticles count={scaleCount(700)} uniforms={heroFlow} />
      <RoleNetwork positions={rolePositions} opacity={netOpacity} labels={labelOpacity} />
      <group position={[0, BUS_Y, 0]} scale={0.6}>
        <BusWorld progress={busProgress} opacity={busOpacity} />
      </group>
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
