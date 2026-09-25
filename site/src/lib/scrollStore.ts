import { clamp } from './math'

/**
 * Mutable scroll + pointer state shared between the DOM and WebGL layers.
 * Written once per frame by the director, read inside useFrame. Nothing
 * here goes through React state, so scrolling never re-renders the tree.
 */
export type SectionState = {
  /** Share of the viewport this section covers, 0..1. */
  weight: number
  /** 0 when its top meets the viewport bottom, 1 when its bottom leaves the top. */
  enter: number
  /** 0..1 across the sticky stretch (top at viewport top → bottom at viewport bottom). */
  pinned: number
}

export const scroll = {
  y: 0,
  velocity: 0,
  progress: 0,
  direction: 1 as 1 | -1,
  pointer: { x: 0, y: 0, sx: 0, sy: 0 },
  sections: {} as Record<string, SectionState>,
}

const elements = new Map<string, HTMLElement>()

export function registerSection(id: string, el: HTMLElement) {
  elements.set(id, el)
  scroll.sections[id] ??= { weight: 0, enter: 0, pinned: 0 }
  return () => {
    if (elements.get(id) === el) elements.delete(id)
  }
}

export function section(id: string): SectionState {
  return (scroll.sections[id] ??= { weight: 0, enter: 0, pinned: 0 })
}

export function measureSections() {
  const vh = window.innerHeight
  for (const [id, el] of elements) {
    const r = el.getBoundingClientRect()
    const s = section(id)
    const overlap = Math.min(r.bottom, vh) - Math.max(r.top, 0)
    s.weight = clamp(overlap / vh)
    s.enter = clamp((vh - r.top) / (r.height + vh))
    s.pinned = r.height > vh + 1 ? clamp(-r.top / (r.height - vh)) : s.enter
  }
  const max = document.documentElement.scrollHeight - vh
  scroll.progress = max > 0 ? clamp(window.scrollY / max) : 0
}
