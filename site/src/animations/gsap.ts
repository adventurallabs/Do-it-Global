import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)
gsap.defaults({ ease: 'expo.out', duration: 1.1 })
ScrollTrigger.config({ ignoreMobileResize: true })

export { gsap, ScrollTrigger }

/** The house curves: quick departure, long settle. Nothing bounces. */
export const EASE = {
  out: 'expo.out',
  inOut: 'power3.inOut',
  soft: 'power2.out',
  scrub: 'none',
} as const

if (import.meta.env.DEV) Object.assign(window, { ScrollTrigger, gsap })
