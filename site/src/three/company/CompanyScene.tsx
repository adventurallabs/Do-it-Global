import { useMemo, useRef } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import * as THREE from 'three'
import { Backdrop, type BackdropLook } from '../common/Backdrop'
import { Dust } from '../common/Dust'
import { OrbitLines, setOrbitOpacity } from '../common/OrbitLines'
import { MorphField, makeUniforms } from './MorphField'
import { scroll, section } from '../../lib/scrollStore'
import { quality, scaleCount } from '../../lib/quality'
import { blendColor, blendNumber, blendVec3, sectionWeights } from '../../lib/blend'
import { damp, remap } from '../../lib/math'

const IDS = ['hero', 'build', 'product', 'philosophy', 'vision'] as const
type V3 = [number, number, number]
const C = (hex: string) => new THREE.Color(hex)

/** One look per chapter. The director blends them by on-screen share. */
const STAGES = {
  cam: [[0, 0, 11], [0, 0.25, 10.8], [0, 0, 12.6], [0, 0, 11.2], [0, 0.2, 10]] as V3[],
  obj: [[0, 0, 0], [3.1, -0.1, 0], [0, 0, 0], [2.7, 0, 0], [0, -0.1, 0]] as V3[],
  objMobile: [[0, 0.95, 0], [0, 1.35, 0], [0, 0.1, 0], [0, 1.5, 0], [0, 0.3, 0]] as V3[],
  scale: [1, 0.95, 0.84, 0.92, 1.12],
  scaleMobile: [0.78, 0.66, 0.6, 0.62, 0.78],
  noise: [1, 0.35, 0.25, 0.4, 0.5],
  pointer: [1, 0.6, 0.25, 0.6, 0.8],
  opacity: [0.95, 0.9, 0.85, 0.8, 0.9],
  orbits: [1, 0.2, 0, 0.3, 0.9],
  colA: [C('#edeae3'), C('#edeae3'), C('#d9c8ff'), C('#edeae3'), C('#e2ebff')],
  colB: [C('#9aa7ff'), C('#7fb6ff'), C('#8b52d1'), C('#b79bff'), C('#6f8bff')],
  dust: [C('#c9ccf5'), C('#b8d2ff'), C('#cdb8ff'), C('#d6d2ff'), C('#b8caff')],
  bgA: [C('#221843'), C('#0f2140'), C('#3a1b66'), C('#1c173a'), C('#13264b')],
  bgB: [C('#0c1a31'), C('#191331'), C('#10173a'), C('#0a1929'), C('#2a1a4a')],
  bgPosA: [[0.74, 0.64], [0.78, 0.5], [0.5, 0.5], [0.8, 0.45], [0.5, 0.36]] as [number, number][],
  bgPosB: [[0.16, 0.22], [0.2, 0.82], [0.2, 0.18], [0.15, 0.2], [0.5, 0.92]] as [number, number][],
  bgIntensity: [1, 0.9, 1.25, 0.85, 1],
}

const BG_AX = STAGES.bgPosA.map((p) => p[0])
const BG_AY = STAGES.bgPosA.map((p) => p[1])
const BG_BX = STAGES.bgPosB.map((p) => p[0])
const BG_BY = STAGES.bgPosB.map((p) => p[1])

export default function CompanyScene() {
  const count = useMemo(() => scaleCount(24000), [])
  const uniforms = useMemo(makeUniforms, [])
  const group = useRef<THREE.Group>(null)
  const orbits = useRef<THREE.Group>(null)
  const camera = useThree((s) => s.camera)
  const size = useThree((s) => s.size)

  const w = useMemo(() => new Array(IDS.length).fill(0), [])
  const look = useRef<BackdropLook>({ base: C('#08090c'), a: STAGES.bgA[0].clone(), b: STAGES.bgB[0].clone(), posA: [...STAGES.bgPosA[0]], posB: [...STAGES.bgPosB[0]], intensity: 1 })
  const dust = useRef(STAGES.dust[0].clone())
  const tmp = useMemo(() => ({ cam: new THREE.Vector3(0, 0, 11), obj: new THREE.Vector3(), camT: new THREE.Vector3(), objT: new THREE.Vector3(), colA: new THREE.Color(), colB: new THREE.Color() }), [])
  const state = useRef({ scale: 1, noise: 1, pointer: 1, opacity: 0, orbits: 1, morph: 0 })

  useFrame((s, dt) => {
    dt = Math.min(dt, 0.05)
    const mobile = size.width < 768
    const has = sectionWeights(IDS, w)
    if (!has) {
      w.fill(0)
      w[IDS.length - 1] = 1
    }

    blendVec3(STAGES.cam, w, tmp.camT)
    blendVec3(mobile ? STAGES.objMobile : STAGES.obj, w, tmp.objT)
    const st = state.current
    const k = 1 - Math.exp(-4 * dt)
    tmp.cam.lerp(tmp.camT, k)
    tmp.obj.lerp(tmp.objT, k)
    st.scale = damp(st.scale, blendNumber(mobile ? STAGES.scaleMobile : STAGES.scale, w), 4, dt)
    st.noise = damp(st.noise, blendNumber(STAGES.noise, w) + Math.min(Math.abs(scroll.velocity) * 0.025, 0.7), 3, dt)
    st.pointer = damp(st.pointer, blendNumber(STAGES.pointer, w), 3, dt)
    st.opacity = damp(st.opacity, blendNumber(STAGES.opacity, w), 1.6, dt)
    st.orbits = damp(st.orbits, blendNumber(STAGES.orbits, w), 3, dt)

    const morph =
      remap(section('build').enter, 0.16, 0.46) +
      remap(section('product').enter, 0.1, 0.3) +
      remap(section('philosophy').pinned, 0.05, 0.75)
    st.morph = damp(st.morph, morph, 2.4, dt)

    const px = scroll.pointer.sx
    const py = scroll.pointer.sy
    camera.position.set(tmp.cam.x + px * 0.35, tmp.cam.y + py * 0.25, tmp.cam.z)
    camera.lookAt(tmp.obj.x * 0.25, tmp.obj.y * 0.25, 0)

    const g = group.current
    if (g) {
      g.position.copy(tmp.obj)
      g.scale.setScalar(st.scale)
      g.rotation.x = -py * 0.12
      g.rotation.y = px * 0.2
    }
    if (orbits.current) {
      orbits.current.rotation.z = s.clock.elapsedTime * 0.03
      setOrbitOpacity(orbits.current, st.orbits)
    }

    const t = s.clock.elapsedTime
    const u = uniforms
    u.uTime.value = t
    u.uMorph.value = st.morph
    u.uNoise.value = st.noise
    u.uOpacity.value = st.opacity
    u.uPointerStrength.value = quality.coarse ? 0 : st.pointer
    u.uPointer.value.set(scroll.pointer.x, scroll.pointer.y)
    u.uAspect.value = size.width / size.height
    u.uPR.value = s.gl.getPixelRatio()
    u.uSize.value = mobile ? 3.6 : 3.2
    u.uSpin.value.set(t * 0.07, t * 0.1, t * 0.035, t * 0.06)
    u.uColA.value.lerp(blendColor(STAGES.colA, w, tmp.colA), k)
    u.uColB.value.lerp(blendColor(STAGES.colB, w, tmp.colB), k)

    const l = look.current
    blendColor(STAGES.bgA, w, l.a)
    blendColor(STAGES.bgB, w, l.b)
    l.posA[0] = blendNumber(BG_AX, w)
    l.posA[1] = blendNumber(BG_AY, w)
    l.posB[0] = blendNumber(BG_BX, w)
    l.posB[1] = blendNumber(BG_BY, w)
    l.intensity = blendNumber(STAGES.bgIntensity, w)
    blendColor(STAGES.dust, w, dust.current)
  })

  const orbitDefs = useMemo(
    () => [
      { rx: 3.4, ry: 1.05, tilt: [0.2, 0.1, -0.35] as V3, opacity: 0.16 },
      { rx: 4.3, ry: 1.6, tilt: [-0.4, 0.3, 0.5] as V3, opacity: 0.09 },
      { rx: 2.7, ry: 2.7, tilt: [1.2, 0, 0] as V3, opacity: 0.07 },
    ],
    [],
  )

  return (
    <>
      <Backdrop look={look} />
      <group ref={group}>
        <MorphField count={count} uniforms={uniforms} />
        <OrbitLines ref={orbits} orbits={orbitDefs} />
      </group>
      <Dust count={1600} color={dust} />
    </>
  )
}
