import { useLayoutEffect, useState, type RefObject } from 'react'

/**
 * Scale factor that fits a fixed-size design (the recreated app screens
 * are laid out at real device points) into whatever box it is given.
 */
export function useFitScale(ref: RefObject<HTMLElement | null>, baseW: number, baseH: number) {
  const [scale, setScale] = useState(1)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const ro = new ResizeObserver(([entry]) => {
      const { width, height } = entry.contentRect
      if (width && height) setScale(Math.min(width / baseW, height / baseH))
    })
    ro.observe(el)
    return () => ro.disconnect()
  }, [ref, baseW, baseH])
  return scale
}
