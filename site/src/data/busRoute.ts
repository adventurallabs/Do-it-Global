// Plain data (no three.js) so DOM sections can share it without pulling in WebGL.
/** Route in the world's local XZ plane. Index 0 is the school, the last stop is the child's. */
export const ROUTE_POINTS: [number, number][] = [
  [-6.2, 2.6],
  [-4.2, 0.6],
  [-2.2, 1.6],
  [-0.4, -0.6],
  [1.8, 0.4],
  [3.4, -1.8],
  [5.6, -0.6],
]
/** Curve parameters (0..1) where each of the six stops sits. */
export const STOP_T = [0, 0.2, 0.38, 0.56, 0.76, 1]
