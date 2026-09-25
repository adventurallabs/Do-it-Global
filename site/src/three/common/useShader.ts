import { useEffect, useMemo } from 'react'
import * as THREE from 'three'

/**
 * Build a ShaderMaterial once, around the exact uniforms object the frame
 * loop mutates. Passing `uniforms` through JSX props copies the uniform
 * wrappers, which silently freezes every primitive uniform (time, morph,
 * opacity) — so every shader in this project is created here instead.
 */
export function useShader(params: THREE.ShaderMaterialParameters) {
  // Shaders and uniforms are fixed for a component's lifetime.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const material = useMemo(() => new THREE.ShaderMaterial(params), [])
  useEffect(() => () => material.dispose(), [material])
  return material
}
