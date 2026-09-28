/**
 * Scroll positions where an animation has fully played out. Tap navigation
 * moves between these, so one tap always lands on a settled frame — never
 * halfway through a transition.
 *
 * Sections with a scrubbed timeline register exact stops; every other
 * section gets sensible ones from its layout (see `collectStops`).
 */
type Provider = () => number[]

const providers = new Map<HTMLElement, Provider>()

export function registerStops(section: HTMLElement, provider: Provider) {
  providers.set(section, provider)
  return () => {
    if (providers.get(section) === provider) providers.delete(section)
  }
}

/**
 * Stops for a section driven by one scrubbed timeline: `times` are points on
 * the timeline (seconds), mapped through its ScrollTrigger's scroll range.
 */
export function timelineStops(tl: gsap.core.Timeline, times: number[]): Provider {
  return () => {
    const st = tl.scrollTrigger
    const dur = tl.duration()
    if (!st || !dur) return []
    return times.map((t) => st.start + (Math.min(t, dur) / dur) * (st.end - st.start))
  }
}

const docTop = (el: HTMLElement) => el.getBoundingClientRect().top + window.scrollY

/** Every stop on the page, ascending, clamped to the scrollable range. */
export function collectStops(root: HTMLElement) {
  const vh = window.innerHeight
  const max = document.documentElement.scrollHeight - vh
  const out: number[] = [0, max]
  for (const sec of root.querySelectorAll<HTMLElement>(':scope > section')) {
    const provided = providers.get(sec)
    if (provided) {
      out.push(...provided())
      continue
    }
    const top = docTop(sec)
    const h = sec.offsetHeight
    out.push(top)
    const pinned = h > vh * 1.2 && sec.querySelector(':scope > .sticky-stage')
    if (pinned) {
      // A pinned, scrubbed stage: split its travel into roughly one-screen
      // steps, ending exactly where the stage releases.
      const travel = h - vh
      const n = Math.max(1, Math.round(travel / vh))
      for (let i = 1; i <= n; i++) out.push(top + (travel * i) / n)
    } else if (h > vh) {
      // Tall flowing content: page through it a screen at a time.
      for (let y = top + vh * 0.8; y < top + h - vh * 0.5; y += vh * 0.8) out.push(y)
    }
  }
  const sorted = out.map((y) => Math.round(Math.max(0, Math.min(max, y)))).sort((a, b) => a - b)
  return sorted.filter((y, i) => i === 0 || y - sorted[i - 1] > 8)
}
