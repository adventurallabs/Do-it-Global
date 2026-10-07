import { forwardRef, useMemo } from 'react'
import { useTexture } from '@react-three/drei'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { useShader } from '../common/useShader'
import { snoise } from '../common/glsl'

export type CoreUniforms = ReturnType<typeof makeCoreUniforms>

/** Palli's violet by default; other products pass their own palette. */
export function makeCoreUniforms(c: { rim: string; deep: string; mid: string } = { rim: '#c8a6ff', deep: '#1a0b33', mid: '#6a33b8' }) {
  return {
    uTime: { value: 0 },
    uGlow: { value: 1 },
    uRim: { value: new THREE.Color(c.rim) },
    uDeep: { value: new THREE.Color(c.deep) },
    uMid: { value: new THREE.Color(c.mid) },
  }
}

/** A soft radial sprite, drawn once on a canvas. */
export function useGlowTexture() {
  return useMemo(() => {
    const c = document.createElement('canvas')
    c.width = c.height = 128
    const g = c.getContext('2d')!
    const grd = g.createRadialGradient(64, 64, 0, 64, 64, 64)
    grd.addColorStop(0, 'rgba(255,255,255,1)')
    grd.addColorStop(0.25, 'rgba(255,255,255,.45)')
    grd.addColorStop(0.6, 'rgba(255,255,255,.08)')
    grd.addColorStop(1, 'rgba(255,255,255,0)')
    g.fillStyle = grd
    g.fillRect(0, 0, 128, 128)
    const t = new THREE.CanvasTexture(c)
    t.colorSpace = THREE.SRGBColorSpace
    return t
  }, [])
}

/**
 * The heart of the page: a body with a living interior, a bright Fresnel
 * rim, a halo, and the product's real mark floating in front of it.
 */
type CoreProps = {
  uniforms: CoreUniforms
  markOpacity: { current: number }
  /** The product mark floating in front of the core (Palli's by default). */
  mark?: string
  /** Its plane size, matching the image's aspect. */
  markSize?: [number, number]
  halo?: string
}

export const EcosystemCore = forwardRef<THREE.Group, CoreProps>(function EcosystemCore({ uniforms, markOpacity, mark: markUrl = '/brand/palli-mark.webp', markSize = [1.12, 1.15], halo = '#7d45d0' }, ref) {
  const mark = useTexture(markUrl)
  mark.colorSpace = THREE.SRGBColorSpace
  const glow = useGlowTexture()

  const coreMat = useShader({
    uniforms: uniforms,
    transparent: true,
    vertexShader: /* glsl */ `
            varying vec3 vN; varying vec3 vV; varying vec3 vP;
            void main(){
              vP = position;
              vec4 mv = modelViewMatrix * vec4(position, 1.0);
              vN = normalize(normalMatrix * normal);
              vV = normalize(-mv.xyz);
              gl_Position = projectionMatrix * mv;
            }
          `,
    fragmentShader: /* glsl */ `
            uniform float uTime, uGlow;
            uniform vec3 uRim, uDeep, uMid;
            varying vec3 vN; varying vec3 vV; varying vec3 vP;
            ${snoise}
            void main(){
              float f = 1.0 - max(dot(vN, vV), 0.0);
              float rim = pow(f, 2.6);
              float n = snoise(vP * 1.6 + vec3(0.0, uTime * 0.15, uTime * 0.08));
              float n2 = snoise(vP * 3.2 - vec3(uTime * 0.1));
              vec3 col = mix(uDeep, uMid, smoothstep(-0.4, 0.9, n) * 0.8 + n2 * 0.1);
              col += uRim * rim * 1.35 * uGlow;
              col += uRim * pow(max(n, 0.0), 3.0) * 0.35 * uGlow;
              gl_FragColor = vec4(col, 0.96);
              #include <colorspace_fragment>
            }
          `,
  })

  return (
    <group ref={ref}>
      <sprite scale={[7.5, 7.5, 1]} renderOrder={-1}>
        <spriteMaterial map={glow} color={halo} transparent opacity={0.55} depthWrite={false} blending={THREE.AdditiveBlending} />
      </sprite>
      <mesh material={coreMat}>
        <sphereGeometry args={[1.15, 96, 96]} />
      </mesh>
      <MarkPlane map={mark} opacity={markOpacity} size={markSize} />
    </group>
  )
})

function MarkPlane({ map, opacity, size }: { map: THREE.Texture; opacity: { current: number }; size: [number, number] }) {
  const mat = useMemo(() => new THREE.MeshBasicMaterial({ map, transparent: true, depthWrite: false, opacity: 1 }), [map])
  useFrame(() => {
    mat.opacity = opacity.current
  })
  return (
    <mesh position={[0, 0.02, 1.2]} material={mat} name="palli-mark">
      <planeGeometry args={size} />
    </mesh>
  )
}
