import { forwardRef, useEffect, useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { RoundedBox } from '@react-three/drei'
import * as THREE from 'three'
import { quality } from '../../lib/quality'

import { ROUTE_POINTS, STOP_T } from '../../data/busRoute'

export function makeRouteCurve() {
  return new THREE.CatmullRomCurve3(ROUTE_POINTS.map(([x, z]) => new THREE.Vector3(x, 0, z)), false, 'catmullrom', 0.4)
}

export type BusWorldHandle = { progress: { current: number }; opacity: { current: number } }

/**
 * A quiet, map-like world for the live-bus story. Scroll drives the bus
 * along the route; the travelled part of the road lights up behind it.
 */
export const BusWorld = forwardRef<THREE.Group, BusWorldHandle>(function BusWorld({ progress, opacity }, ref) {
  const curve = useMemo(makeRouteCurve, [])
  const tube = useMemo(() => new THREE.TubeGeometry(curve, 240, 0.06, 8, false), [curve])
  const halo = useMemo(() => new THREE.TubeGeometry(curve, 240, 0.17, 8, false), [curve])
  const bus = useRef<THREE.Group>(null)
  const light = useRef<THREE.Mesh>(null)
  const tmp = useMemo(() => ({ p: new THREE.Vector3(), t: new THREE.Vector3(), look: new THREE.Vector3() }), [])

  // Materials are built here (not as JSX) so the uniform objects the frame
  // loop writes are exactly the ones the GPU programs read.
  const mats = useMemo(() => {
    const route = { uProgress: { value: 0 }, uOpacity: { value: 0 }, uTime: { value: 0 } }
    const grid = { uOpacity: { value: 0 } }
    return {
      route,
      grid,
      halo: new THREE.ShaderMaterial({ uniforms: route, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, vertexShader: routeVertex, fragmentShader: routeFragment(0.12) }),
      tube: new THREE.ShaderMaterial({ uniforms: route, transparent: true, depthWrite: false, vertexShader: routeVertex, fragmentShader: routeFragment(1) }),
      ground: new THREE.ShaderMaterial({ uniforms: grid, transparent: true, depthWrite: false, vertexShader: gridVertex, fragmentShader: gridFragment }),
    }
  }, [])
  const routeUniforms = mats.route
  const gridUniforms = mats.grid

  const stops = useMemo(() => STOP_T.map((t) => curve.getPointAt(t)), [curve])

  // Low-poly blocks, kept off the road.
  const blocks = useMemo(() => {
    const n = quality.tier === 'high' ? 110 : 60
    const m = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshStandardMaterial({ color: '#1c2236', emissive: '#0b1020', roughness: 0.75, metalness: 0.15, transparent: true }), n)
    const d = new THREE.Object3D()
    const samples = curve.getSpacedPoints(120)
    let placed = 0
    let guard = 0
    while (placed < n && guard++ < 4000) {
      const x = (Math.random() - 0.5) * 18
      const z = (Math.random() - 0.5) * 11
      if (samples.some((s) => Math.hypot(s.x - x, s.z - z) < 0.95)) continue
      const h = 0.06 + Math.pow(Math.random(), 2.4) * 0.55
      const w = 0.25 + Math.random() * 0.45
      d.position.set(x, h / 2, z)
      d.scale.set(w, h, 0.25 + Math.random() * 0.45)
      d.rotation.y = Math.round(Math.random()) * 0.08
      d.updateMatrix()
      m.setMatrixAt(placed++, d.matrix)
    }
    m.count = placed
    return m
  }, [curve])

  useEffect(
    () => () => {
      tube.dispose()
      halo.dispose()
      mats.halo.dispose()
      mats.tube.dispose()
      mats.ground.dispose()
      blocks.geometry.dispose()
      ;(blocks.material as THREE.Material).dispose()
    },
    [tube, halo, blocks, mats],
  )

  useFrame((s) => {
    const o = opacity.current
    const t = THREE.MathUtils.clamp(progress.current, 0, 1)
    routeUniforms.uProgress.value = t
    routeUniforms.uOpacity.value = o
    routeUniforms.uTime.value = s.clock.elapsedTime
    gridUniforms.uOpacity.value = o
    ;(blocks.material as THREE.MeshStandardMaterial).opacity = o
    if (bus.current) {
      curve.getPointAt(t, tmp.p)
      curve.getTangentAt(t, tmp.t)
      bus.current.position.copy(tmp.p)
      bus.current.position.y = 0.21
      tmp.look.copy(tmp.p).add(tmp.t)
      tmp.look.y = 0.21
      // lookAt wants world space; the curve is in this world's local space.
      bus.current.parent?.localToWorld(tmp.look)
      bus.current.lookAt(tmp.look)
      bus.current.visible = o > 0.02
    }
    if (light.current) (light.current.material as THREE.MeshBasicMaterial).opacity = 0.14 * o
  })

  return (
    <group ref={ref}>
      <ambientLight intensity={0.5} />
      <directionalLight position={[4, 8, 5]} intensity={1.6} color="#dfe8ff" />
      {/* Ground grid */}
      <mesh rotation-x={-Math.PI / 2} position-y={-0.01} material={mats.ground}>
        <planeGeometry args={[40, 26]} />
      </mesh>
      <primitive object={blocks} />
      {/* Route */}
      <mesh geometry={halo} material={mats.halo} />
      <mesh geometry={tube} material={mats.tube} />
      {/* Stops */}
      {stops.map((p, i) => (
        <Stop key={i} position={p} kind={i === 0 ? 'school' : i === stops.length - 1 ? 'child' : 'stop'} opacity={opacity} />
      ))}
      {/* Bus */}
      <group ref={bus} scale={1.35}>
        <RoundedBox args={[0.3, 0.26, 0.62]} radius={0.06} smoothness={3}>
          <meshStandardMaterial color="#f5c542" roughness={0.35} metalness={0.2} emissive="#3a2600" />
        </RoundedBox>
        <mesh position={[0, 0.05, 0]}>
          <boxGeometry args={[0.305, 0.07, 0.5]} />
          <meshBasicMaterial color="#bfe6ff" />
        </mesh>
        <mesh ref={light} position={[0, -0.14, 0.9]} rotation-x={-Math.PI / 2}>
          <planeGeometry args={[0.5, 1.1]} />
          <meshBasicMaterial color="#fff2c4" transparent opacity={0.5} depthWrite={false} blending={THREE.AdditiveBlending} />
        </mesh>
      </group>
    </group>
  )
})

const gridVertex = /* glsl */ `varying vec3 vW; void main(){ vW = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`
const gridFragment = /* glsl */ `
  uniform float uOpacity; varying vec3 vW;
  float line(float v, float w){ float g = abs(fract(v - 0.5) - 0.5) / fwidth(v); return 1.0 - min(g / w, 1.0); }
  void main(){
    vec2 p = vW.xy;
    float g = max(line(p.x, 1.0), line(p.y, 1.0)) * 0.5 + max(line(p.x * 0.25, 1.2), line(p.y * 0.25, 1.2)) * 0.6;
    float fade = smoothstep(13.0, 3.0, length(p));
    gl_FragColor = vec4(vec3(0.42, 0.55, 0.85), g * fade * 0.28 * uOpacity);
    #include <colorspace_fragment>
  }
`
const routeVertex = /* glsl */ `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`
const routeFragment = (strength: number) => /* glsl */ `
  uniform float uProgress, uOpacity, uTime; varying vec2 vUv;
  void main(){
    float done = step(vUv.x, uProgress);
    float pulse = 0.5 + 0.5 * sin((vUv.x - uTime * 0.25) * 60.0);
    vec3 lit = vec3(0.13, 0.77, 0.37);
    vec3 dim = vec3(0.35, 0.45, 0.7);
    vec3 col = mix(dim * (0.6 + pulse * 0.4), lit, done);
    float a = mix(0.45, 1.0, done) * ${strength.toFixed(2)} * uOpacity;
    gl_FragColor = vec4(col, a);
    #include <colorspace_fragment>
  }
`

function Stop({ position, kind, opacity }: { position: THREE.Vector3; kind: 'school' | 'child' | 'stop'; opacity: { current: number } }) {
  const color = kind === 'child' ? '#2F6BFF' : kind === 'school' ? '#C9A24A' : '#dfe6f5'
  const mats = useRef<THREE.Material[]>([])
  useFrame(() => {
    for (const m of mats.current) if (m) (m as THREE.MeshBasicMaterial).opacity = (m.userData.base ?? 1) * opacity.current
  })
  const reg = (base: number) => (m: THREE.Material | null) => {
    if (m) {
      m.userData.base = base
      if (!mats.current.includes(m)) mats.current.push(m)
    }
  }
  const h = kind === 'stop' ? 0.55 : 1.1
  return (
    <group position={position}>
      <mesh rotation-x={-Math.PI / 2} position-y={0.02}>
        <ringGeometry args={[0.16, 0.22, 40]} />
        <meshBasicMaterial ref={reg(0.9)} color={color} transparent depthWrite={false} />
      </mesh>
      <mesh position-y={h / 2}>
        <cylinderGeometry args={[0.012, 0.012, h, 6]} />
        <meshBasicMaterial ref={reg(0.55)} color={color} transparent depthWrite={false} blending={THREE.AdditiveBlending} />
      </mesh>
      <mesh position-y={h}>
        <sphereGeometry args={[kind === 'stop' ? 0.05 : 0.09, 16, 16]} />
        <meshBasicMaterial ref={reg(1)} color={color} transparent />
      </mesh>
    </group>
  )
}
