import { useCallback, useRef } from 'react'
import { registerSection } from '../lib/scrollStore'

/** Ref callback that makes an element report its scroll state to the store. */
export function useSection<T extends HTMLElement = HTMLElement>(id: string) {
  const cleanup = useRef<(() => void) | null>(null)
  return useCallback(
    (el: T | null) => {
      cleanup.current?.()
      cleanup.current = el ? registerSection(id, el) : null
    },
    [id],
  )
}
