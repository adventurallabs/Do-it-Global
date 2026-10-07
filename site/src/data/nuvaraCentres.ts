/**
 * Fictional example centres, used to show that every centre gets Nuvara
 * under its own name and on its own server.
 */
export type Centre = {
  name: string
  /** Shorter name for chips and labels. */
  short: string
  /** The centre's server, as shown in the diagram. */
  server: string
  /** Accent for chips and diagram lines on the dark page. */
  glow: string
}

export const CENTRES: Centre[] = [
  { name: 'Little Steps Therapy Centre', short: 'Little Steps', server: 'little-steps', glow: '#FF9A6E' },
  { name: 'Bloom Child Development Centre', short: 'Bloom', server: 'bloom', glow: '#7CC8EF' },
  { name: 'Sunrise Kids Therapy', short: 'Sunrise Kids', server: 'sunrise-kids', glow: '#C3C8F5' },
]
