import { useEffect, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { useShader } from '../common/useShader'
import { scaleCount } from '../../lib/quality'
import { softPoint } from './glsl'

type Props = {
  count?: number
  spread?: [number, number, number]
  center?: [number, number, number]
  color?: React.MutableRefObject<THREE.Color>
  size?: number
  opacity?: number
}

/** Slow, deep field of motes that gives the camera something to move past. */
export function Dust({ count = 1400, spread = [30, 20, 30], center = [0, 0, -4], color, size = 2.2, opacity = 0.55 }: Props) {
  const n = scaleCount(count)
  const geometry = useMemo(() => {
    const g = new THREE.BufferGeometry()
    const pos = new Float32Array(n * 3)
    const rnd = new Float32Array(n)
    for (let i = 0; i < n; i++) {
      pos[i * 3] = (Math.random() - 0.5) * spread[0]
      pos[i * 3 + 1] = (Math.random() - 0.5) * spread[1]
      pos[i * 3 + 2] = (Math.random() - 0.5) * spread[2]
      rnd[i] = Math.random()
    }
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3))
    g.setAttribute('aRand', new THREE.BufferAttribute(rnd, 1))
    return g
  }, [n, spread])

  useEffect(() => () => geometry.dispose(), [geometry])

  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uSize: { value: size },
      uPR: { value: 1 },
      uColor: { value: color ? color.current.clone() : new THREE.Color('#cfd3ff') },
      uOpacity: { value: opacity },
    }),
    [],
  )

  useFrame((state, dt) => {
    uniforms.uTime.value = state.clock.elapsedTime
    uniforms.uPR.value = state.gl.getPixelRatio()
    if (color) uniforms.uColor.value.lerp(color.current, 1 - Math.exp(-2 * dt))
  })

  const dustMat = useShader({
    uniforms: uniforms,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    vertexShader: /* glsl */ `
          uniform float uTime, uSize, uPR;
          attribute float aRand;
          varying float vA;
          void main(){
            vec3 p = position;
            p.y += sin(uTime * 0.12 + aRand * 40.0) * 0.35;
            p.x += cos(uTime * 0.09 + aRand * 25.0) * 0.35;
            vec4 mv = modelViewMatrix * vec4(p, 1.0);
            gl_Position = projectionMatrix * mv;
            gl_PointSize = uSize * uPR * (0.4 + aRand) * (8.0 / max(1.0, -mv.z));
            vA = (0.25 + 0.75 * aRand) * smoothstep(40.0, 8.0, -mv.z) * smoothstep(0.5, 3.0, -mv.z);
          }
        `,
    fragmentShader: /* glsl */ `
          uniform vec3 uColor; uniform float uOpacity;
          varying float vA;
          ${softPoint}
          void main(){
            gl_FragColor = vec4(uColor, softPoint() * vA * uOpacity);
            #include <colorspace_fragment>
          }
        `,
  })

  return (
    <points material={dustMat} geometry={geometry} position={center} frustumCulled={false} />
  )
}
