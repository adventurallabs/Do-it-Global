import * as THREE from 'three'
import { section } from './scrollStore'

/**
 * Normalised visibility weights for a list of sections. Adjacent sections
 * cross-fade naturally: while one scrolls out the next scrolls in and their
 * weights always sum to one.
 */
export function sectionWeights(ids: readonly string[], out: number[]): boolean {
  let sum = 0
  for (let i = 0; i < ids.length; i++) {
    out[i] = section(ids[i]).weight
    sum += out[i]
  }
  if (sum < 1e-4) return false
  for (let i = 0; i < ids.length; i++) out[i] /= sum
  return true
}

export function blendNumber(values: readonly number[], w: readonly number[]) {
  let v = 0
  for (let i = 0; i < values.length; i++) v += values[i] * w[i]
  return v
}

export function blendVec3(values: readonly (readonly [number, number, number])[], w: readonly number[], out: THREE.Vector3) {
  out.set(0, 0, 0)
  for (let i = 0; i < values.length; i++) {
    out.x += values[i][0] * w[i]
    out.y += values[i][1] * w[i]
    out.z += values[i][2] * w[i]
  }
  return out
}

export function blendColor(values: readonly THREE.Color[], w: readonly number[], out: THREE.Color) {
  out.setRGB(0, 0, 0)
  for (let i = 0; i < values.length; i++) {
    out.r += values[i].r * w[i]
    out.g += values[i].g * w[i]
    out.b += values[i].b * w[i]
  }
  return out
}
