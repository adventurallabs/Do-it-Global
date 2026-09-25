import { forwardRef, useEffect, useMemo } from 'react'
import * as THREE from 'three'
import { useShader } from '../common/useShader'
import { softPoint } from '../common/glsl'

export type RingUniforms = ReturnType<typeof makeRingUniforms>

export function makeRingUniforms(a: string, b: string) {
  return {
    uTime: { value: 0 },
    uColA: { value: new THREE.Color(a) },
    uColB: { value: new THREE.Color(b) },
    uOpacity: { value: 1 },
    uPR: { value: 1 },
    uSize: { value: 3.2 },
    uSpeed: { value: 0.08 },
  }
}

/**
 * One of the two app orbits around the core. Particles stream around the
 * ring (angular speed in the shader), denser toward a travelling "head".
 */
export const OrbitRing = forwardRef<THREE.Points, { count: number; radius: number; uniforms: RingUniforms }>(function OrbitRing({ count, radius, uniforms }, ref) {
  const geometry = useMemo(() => {
    const g = new THREE.BufferGeometry()
    const pos = new Float32Array(count * 3)
    const data = new Float32Array(count * 3)
    for (let i = 0; i < count; i++) {
      const a = Math.random() * Math.PI * 2
      data[i * 3] = a
      data[i * 3 + 1] = (Math.random() - 0.5) * (Math.random() < 0.8 ? 0.08 : 0.5)
      data[i * 3 + 2] = Math.random()
    }
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3))
    g.setAttribute('aData', new THREE.BufferAttribute(data, 3))
    return g
  }, [count])
  useEffect(() => () => geometry.dispose(), [geometry])

  const ringMat = useShader({
    uniforms: { ...uniforms, uR: { value: radius } },
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    vertexShader: /* glsl */ `
          uniform float uTime, uR, uPR, uSize, uSpeed;
          uniform vec3 uColA, uColB;
          attribute vec3 aData;
          varying vec3 vColor; varying float vA;
          void main(){
            float a = aData.x + uTime * uSpeed * (0.6 + aData.z * 0.8);
            float r = uR + aData.y;
            vec3 p = vec3(cos(a) * r, sin(a) * r, aData.y * 0.6);
            vec4 mv = modelViewMatrix * vec4(p, 1.0);
            gl_Position = projectionMatrix * mv;
            float head = pow(0.5 + 0.5 * cos(a - uTime * 0.5), 6.0);
            gl_PointSize = uSize * uPR * (0.4 + aData.z + head * 1.2) * (9.0 / -mv.z);
            vColor = mix(uColA, uColB, aData.z);
            vA = (0.35 + head * 0.9) * smoothstep(24.0, 6.0, -mv.z);
          }
        `,
    fragmentShader: /* glsl */ `
          uniform float uOpacity;
          varying vec3 vColor; varying float vA;
          ${softPoint}
          void main(){
            gl_FragColor = vec4(vColor, softPoint() * vA * uOpacity);
            #include <colorspace_fragment>
          }
        `,
  })

  return (
    <points material={ringMat} ref={ref} geometry={geometry} frustumCulled={false} />
  )
})
