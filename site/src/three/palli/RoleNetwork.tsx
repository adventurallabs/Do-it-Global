import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'
import { FlowParticles, makeFlowUniforms } from './FlowParticles'
import { useGlowTexture } from './EcosystemCore'
import { scaleCount } from '../../lib/quality'

export const ROLES = [
  { id: 'admin', label: 'Administrators', app: 'PalliCore', color: '#E2C275' },
  { id: 'teacher', label: 'Teachers', app: 'PalliCore', color: '#C9A24A' },
  { id: 'parent', label: 'Parents', app: 'PalliConnect', color: '#3EC6FF' },
  { id: 'student', label: 'Students', app: 'PalliConnect', color: '#7FB2FF' },
] as const

/** Which roles exchange light through the core. School side ↔ family side. */
const PAIRS: [number, number][] = [
  [0, 2],
  [1, 3],
  [1, 2],
  [0, 3],
]

type Props = {
  /** Mutable world positions, one per role, written by the scene each frame. */
  positions: THREE.Vector3[]
  opacity: { current: number }
  labels: { current: number }
}

/** The four roles of a school as nodes, with the traffic between them. */
export function RoleNetwork({ positions, opacity, labels }: Props) {
  const glow = useGlowTexture()
  const nodes = useRef<(THREE.Group | null)[]>([])
  const labelEls = useRef<(HTMLDivElement | null)[]>([])
  const sprites = useRef<(THREE.SpriteMaterial | null)[]>([])
  const flows = useMemo(() => PAIRS.map(([a, b]) => makeFlowUniforms(ROLES[a].color, '#b79bff', ROLES[b].color)), [])
  const count = scaleCount(420)

  useFrame((s) => {
    const o = opacity.current
    positions.forEach((p, i) => {
      const n = nodes.current[i]
      if (n) {
        n.position.copy(p)
        n.visible = o > 0.01
      }
      const m = sprites.current[i]
      if (m) m.opacity = o * 0.9
      const el = labelEls.current[i]
      if (el) el.style.opacity = String(labels.current * o)
    })
    flows.forEach((u, i) => {
      const [a, b] = PAIRS[i]
      u.uA.value.copy(positions[a])
      u.uB.value.copy(positions[b])
      u.uTime.value = s.clock.elapsedTime
      u.uOpacity.value = o
      u.uPR.value = s.gl.getPixelRatio()
    })
  })

  return (
    <group>
      {ROLES.map((r, i) => (
        <group key={r.id} ref={(g) => void (nodes.current[i] = g)}>
          <sprite scale={[1.3, 1.3, 1]}>
            <spriteMaterial ref={(m) => void (sprites.current[i] = m)} map={glow} color={r.color} transparent depthWrite={false} blending={THREE.AdditiveBlending} />
          </sprite>
          <mesh>
            <sphereGeometry args={[0.09, 20, 20]} />
            <meshBasicMaterial color="#ffffff" />
          </mesh>
          <Html center position={[0, -0.55, 0]} zIndexRange={[5, 0]} style={{ pointerEvents: 'none' }}>
            <div ref={(el) => void (labelEls.current[i] = el)} className="whitespace-nowrap text-center" style={{ opacity: 0 }}>
              <div className="text-[0.95rem] font-medium tracking-[-0.01em] text-bone">{r.label}</div>
              <div className="t-label mt-1 text-[0.58rem]" style={{ color: r.color }}>
                {r.app}
              </div>
            </div>
          </Html>
        </group>
      ))}
      {flows.map((u, i) => (
        <FlowParticles key={i} count={count} uniforms={u} spread={0.12} />
      ))}
    </group>
  )
}
