import { forwardRef, useEffect, useMemo } from 'react'
import * as THREE from 'three'
import { useShader } from '../common/useShader'
import { softPoint } from '../common/glsl'

export type FlowUniforms = ReturnType<typeof makeFlowUniforms>

export function makeFlowUniforms(from: string, via: string, to: string) {
  return {
    uTime: { value: 0 },
    uA: { value: new THREE.Vector3(-3, 1, 0) },
    uB: { value: new THREE.Vector3(3, -1, 0) },
    uC: { value: new THREE.Vector3(0, 0, 0) },
    uColA: { value: new THREE.Color(from) },
    uColC: { value: new THREE.Color(via) },
    uColB: { value: new THREE.Color(to) },
    uOpacity: { value: 1 },
    uSpeed: { value: 0.12 },
    uSize: { value: 5 },
    uPR: { value: 1 },
  }
}

/**
 * Light travelling between two points through a third (the Palli core).
 * The curve lives in the vertex shader, so moving endpoints costs nothing:
 * half the particles run A→B, half B→A — information goes both ways.
 */
export const FlowParticles = forwardRef<THREE.Points, { count: number; uniforms: FlowUniforms; spread?: number }>(function FlowParticles({ count, uniforms, spread = 0.18 }, ref) {
  const geometry = useMemo(() => {
    const g = new THREE.BufferGeometry()
    const pos = new Float32Array(count * 3)
    const t = new Float32Array(count)
    const off = new Float32Array(count * 3)
    const dir = new Float32Array(count)
    for (let i = 0; i < count; i++) {
      t[i] = Math.random()
      off[i * 3] = (Math.random() - 0.5) * spread
      off[i * 3 + 1] = (Math.random() - 0.5) * spread
      off[i * 3 + 2] = (Math.random() - 0.5) * spread
      dir[i] = i % 2
    }
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3))
    g.setAttribute('aT', new THREE.BufferAttribute(t, 1))
    g.setAttribute('aOff', new THREE.BufferAttribute(off, 3))
    g.setAttribute('aDir', new THREE.BufferAttribute(dir, 1))
    return g
  }, [count, spread])
  useEffect(() => () => geometry.dispose(), [geometry])

  const flowMat = useShader({
    uniforms: uniforms,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    vertexShader: /* glsl */ `
          uniform float uTime, uSpeed, uSize, uPR;
          uniform vec3 uA, uB, uC, uColA, uColB, uColC;
          attribute float aT, aDir;
          attribute vec3 aOff;
          varying vec3 vColor;
          varying float vA;
          void main(){
            float t = fract(aT + uTime * uSpeed * (0.7 + aT * 0.6));
            float s = aDir > 0.5 ? 1.0 - t : t;
            vec3 p = (1.0 - s) * (1.0 - s) * uA + 2.0 * (1.0 - s) * s * uC + s * s * uB;
            float thin = sin(s * 3.14159);
            p += aOff * (0.35 + thin * 1.6);
            vec4 mv = modelViewMatrix * vec4(p, 1.0);
            gl_Position = projectionMatrix * mv;
            gl_PointSize = uSize * uPR * (0.5 + aT) * (8.0 / -mv.z);
            vColor = s < 0.5 ? mix(uColA, uColC, s * 2.0) : mix(uColC, uColB, s * 2.0 - 1.0);
            vA = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.92, 1.0, t));
          }
        `,
    fragmentShader: /* glsl */ `
          uniform float uOpacity;
          varying vec3 vColor;
          varying float vA;
          ${softPoint}
          void main(){
            gl_FragColor = vec4(vColor, softPoint() * vA * uOpacity);
            #include <colorspace_fragment>
          }
        `,
  })

  return (
    <points material={flowMat} ref={ref} geometry={geometry} frustumCulled={false} />
  )
})
