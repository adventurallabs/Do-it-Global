import { forwardRef, useEffect, useMemo } from 'react'
import * as THREE from 'three'
import { useShader } from '../common/useShader'
import { rotations, snoise, softPoint } from '../common/glsl'
import { globe, portal, seed, stack } from './morphTargets'

export type MorphUniforms = ReturnType<typeof makeUniforms>

export function makeUniforms() {
  return {
    uTime: { value: 0 },
    uMorph: { value: 0 },
    uSize: { value: 3.2 },
    uPR: { value: 1 },
    uNoise: { value: 1 },
    uOpacity: { value: 0.9 },
    uColA: { value: new THREE.Color('#edeae3') },
    uColB: { value: new THREE.Color('#a9b4ff') },
    uPointer: { value: new THREE.Vector2(9, 9) },
    uPointerStrength: { value: 1 },
    uAspect: { value: 1 },
    uSpin: { value: new THREE.Vector4() },
  }
}

const vertex = /* glsl */ `
  uniform float uTime, uMorph, uSize, uPR, uNoise, uPointerStrength, uAspect;
  uniform vec2 uPointer;
  uniform vec4 uSpin;
  uniform vec3 uColA, uColB;
  attribute vec3 aP1, aP2, aP3;
  attribute float aRand;
  varying vec3 vColor;
  varying float vAlpha;
  ${snoise}
  ${rotations}

  vec3 stageAt(float i){
    if (i < 0.5) return rotY(position, uSpin.x);
    if (i < 1.5) return rotY(aP1, uSpin.y);
    if (i < 2.5) return rotZ(aP2, uSpin.z);
    return rotY(rotX(aP3, 0.35), uSpin.w);
  }

  void main(){
    float m = clamp(uMorph, 0.0, 3.0);
    float seg = min(floor(m), 2.0);
    float t = m - seg;
    // Each particle leaves on its own beat, so shapes pour into each other.
    float d = aRand * 0.45;
    float tt = smoothstep(d, d + 0.55, t);
    vec3 a = stageAt(seg);
    vec3 b = stageAt(seg + 1.0);
    vec3 p = mix(a, b, tt);

    float flow = sin(tt * 3.14159);
    vec3 q = p * 0.55 + uTime * 0.12;
    vec3 n = vec3(snoise(q), snoise(q + 17.3), snoise(q + 41.7));
    p += n * (flow * 1.1 + 0.05 * uNoise);

    // The seed breathes: slow ridges travelling over the surface.
    float seedW = 1.0 - clamp(m, 0.0, 1.0);
    float ridge = snoise(normalize(position) * 1.3 + vec3(0.0, uTime * 0.18, uTime * 0.07));
    p += normalize(p + 1e-4) * ridge * 0.32 * uNoise * seedW;

    vec4 mv = modelViewMatrix * vec4(p, 1.0);

    // Part around the pointer, in screen space.
    vec4 clip = projectionMatrix * mv;
    vec2 ndc = clip.xy / clip.w;
    vec2 dir = (ndc - uPointer) * vec2(uAspect, 1.0);
    float f = exp(-dot(dir, dir) * 14.0) * uPointerStrength;
    mv.xy += normalize(dir + 1e-4) * f * 0.45;

    gl_Position = projectionMatrix * mv;
    float s = uSize * (0.35 + aRand * aRand * 1.5);
    gl_PointSize = s * uPR * (10.0 / -mv.z) * (1.0 + f * 1.5);

    float depth = smoothstep(19.0, 8.0, -mv.z);
    vColor = mix(uColA, uColB, fract(aRand * 7.13));
    vColor = mix(vColor, vec3(1.0), f * 0.6);
    vAlpha = (0.3 + 0.7 * depth) * (0.5 + 0.5 * fract(aRand * 3.71)) * (1.0 + flow * 0.4);
  }
`

const fragment = /* glsl */ `
  uniform float uOpacity;
  varying vec3 vColor;
  varying float vAlpha;
  ${softPoint}
  void main(){
    gl_FragColor = vec4(vColor, softPoint() * vAlpha * uOpacity);
    #include <colorspace_fragment>
  }
`

type Props = { count: number; uniforms: MorphUniforms }

export const MorphField = forwardRef<THREE.Points, Props>(function MorphField({ count, uniforms }, ref) {
  const geometry = useMemo(() => {
    const g = new THREE.BufferGeometry()
    g.setAttribute('position', new THREE.BufferAttribute(seed(count), 3))
    g.setAttribute('aP1', new THREE.BufferAttribute(stack(count), 3))
    g.setAttribute('aP2', new THREE.BufferAttribute(portal(count), 3))
    g.setAttribute('aP3', new THREE.BufferAttribute(globe(count), 3))
    const r = new Float32Array(count)
    for (let i = 0; i < count; i++) r[i] = Math.random()
    g.setAttribute('aRand', new THREE.BufferAttribute(r, 1))
    return g
  }, [count])

  useEffect(() => () => geometry.dispose(), [geometry])

  const fieldMat = useShader({
    uniforms: uniforms,
    vertexShader: vertex,
    fragmentShader: fragment,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  })

  return (
    <points material={fieldMat} ref={ref} geometry={geometry} frustumCulled={false} />
  )
})
