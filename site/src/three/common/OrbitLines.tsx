import { forwardRef, useEffect, useMemo } from 'react'
import * as THREE from 'three'

type Orbit = { rx: number; ry: number; tilt: [number, number, number]; opacity?: number }

/** Thin elliptical orbits — the only "hard" geometry in the scenes. */
export const OrbitLines = forwardRef<THREE.Group, { orbits: Orbit[]; color?: string }>(function OrbitLines({ orbits, color = '#edeae3' }, ref) {
  const lines = useMemo(
    () =>
      orbits.map((o) => {
        const pts: THREE.Vector3[] = []
        const seg = 256
        for (let i = 0; i < seg; i++) {
          const a = (i / seg) * Math.PI * 2
          pts.push(new THREE.Vector3(Math.cos(a) * o.rx, Math.sin(a) * o.ry, 0))
        }
        const g = new THREE.BufferGeometry().setFromPoints(pts)
        const m = new THREE.LineBasicMaterial({ color, transparent: true, opacity: o.opacity ?? 0.14, depthWrite: false })
        m.userData.base = o.opacity ?? 0.14
        const line = new THREE.LineLoop(g, m)
        line.rotation.set(...o.tilt)
        return line
      }),
    [orbits, color],
  )

  useEffect(
    () => () =>
      lines.forEach((l) => {
        l.geometry.dispose()
        ;(l.material as THREE.Material).dispose()
      }),
    [lines],
  )

  return (
    <group ref={ref}>
      {lines.map((l, i) => (
        <primitive key={i} object={l} />
      ))}
    </group>
  )
})

/** Scale every line's opacity in a group built by OrbitLines. */
export function setOrbitOpacity(group: THREE.Group | null, k: number) {
  if (!group) return
  group.traverse((o) => {
    const m = (o as THREE.LineLoop).material as THREE.LineBasicMaterial | undefined
    if (m && 'opacity' in m) m.opacity = (m.userData.base ?? 0.14) * k
  })
}
