import { useMemo } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import * as THREE from 'three'
import { useShader } from '../common/useShader'

export type BackdropLook = {
  base: THREE.Color
  a: THREE.Color
  b: THREE.Color
  /** Blob centres in UV space. */
  posA: [number, number]
  posB: [number, number]
  intensity: number
}

/**
 * Screen-filling gradient haze drawn behind everything. Its look is
 * blended from whatever the scroll director hands it each frame.
 */
export function Backdrop({ look }: { look: React.MutableRefObject<BackdropLook> }) {
  const size = useThree((s) => s.size)
  const tmpV = useMemo(() => new THREE.Vector2(), [])

  const uniforms = useMemo(
    () => ({
      uBase: { value: look.current.base.clone() },
      uA: { value: look.current.a.clone() },
      uB: { value: look.current.b.clone() },
      uPosA: { value: new THREE.Vector2(...look.current.posA) },
      uPosB: { value: new THREE.Vector2(...look.current.posB) },
      uIntensity: { value: look.current.intensity },
      uAspect: { value: 1 },
      uTime: { value: 0 },
    }),
    [],
  )

  useFrame((state, dt) => {
    const u = uniforms
    const l = look.current
    const k = 1 - Math.exp(-3 * dt)
    u.uBase.value.lerp(l.base, k)
    u.uA.value.lerp(l.a, k)
    u.uB.value.lerp(l.b, k)
    u.uPosA.value.lerp(tmpV.set(l.posA[0], l.posA[1]), k)
    u.uPosB.value.lerp(tmpV.set(l.posB[0], l.posB[1]), k)
    u.uIntensity.value += (l.intensity - u.uIntensity.value) * k
    u.uAspect.value = size.width / size.height
    u.uTime.value = state.clock.elapsedTime
  })

  const backdropMat = useShader({
    uniforms: uniforms,
    depthTest: false,
    depthWrite: false,
    vertexShader: /* glsl */ `
          varying vec2 vUv;
          void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.9999, 1.0); }
        `,
    fragmentShader: /* glsl */ `
          uniform vec3 uBase, uA, uB;
          uniform vec2 uPosA, uPosB;
          uniform float uIntensity, uAspect, uTime;
          varying vec2 vUv;
          void main(){
            vec2 p = vec2(vUv.x * uAspect, vUv.y);
            vec2 a = vec2(uPosA.x * uAspect, uPosA.y) + 0.04 * vec2(sin(uTime*0.13), cos(uTime*0.11));
            vec2 b = vec2(uPosB.x * uAspect, uPosB.y) + 0.05 * vec2(cos(uTime*0.09), sin(uTime*0.12));
            float fa = smoothstep(1.05, 0.0, distance(p, a));
            float fb = smoothstep(0.95, 0.0, distance(p, b));
            vec3 col = uBase + (uA * fa * fa + uB * fb * fb) * uIntensity;
            col += (fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
            gl_FragColor = vec4(col, 1.0);
            #include <colorspace_fragment>
          }
        `,
  })

  return (
    <mesh material={backdropMat} frustumCulled={false} renderOrder={-100}>
      <planeGeometry args={[2, 2]} />
    </mesh>
  )
}
