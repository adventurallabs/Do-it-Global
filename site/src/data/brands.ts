/**
 * Fictional example schools used to show how one Palli build is re-branded
 * per school. Mirrors what a school's `school_settings` row carries in the
 * apps: name, crest (logo) and primary colour.
 */
export type SchoolBrand = {
  name: string
  /** Name under the app icon on a phone's home screen. */
  short: string
  initials: string
  place: string
  color: string
  /** Deeper shade for gradients. */
  deep: string
  /** Light accent for glows and chips. */
  soft: string
  crest: 'shield' | 'circle' | 'star'
}

export const BRANDS: SchoolBrand[] = [
  { name: 'Riverside Public School', short: 'Riverside', initials: 'RPS', place: 'Example school', color: '#1E4FD8', deep: '#0B1E52', soft: '#7FB2FF', crest: 'shield' },
  { name: 'Green Valley Academy', short: 'Green Valley', initials: 'GVA', place: 'Example school', color: '#15803D', deep: '#052E1A', soft: '#86EFAC', crest: 'circle' },
  { name: 'Sunrise Vidyalaya', short: 'Sunrise', initials: 'SV', place: 'Example school', color: '#C2410C', deep: '#431407', soft: '#FDBA74', crest: 'star' },
]

/**
 * Feature switches, named after the keys in PalliConnect's feature registry
 * (lib/core/features/feature_registry.dart). Today and Messages are always on.
 */
export const MODULES: { key: string; label: string; always?: boolean }[] = [
  { key: 'today', label: 'Today', always: true },
  { key: 'messages', label: 'Messages', always: true },
  { key: 'homework', label: 'Homework' },
  { key: 'diary', label: 'Class diary' },
  { key: 'attendance', label: 'Attendance' },
  { key: 'marks', label: 'Exams & results' },
  { key: 'timetable', label: 'Timetable' },
  { key: 'announcements', label: 'Announcements' },
  { key: 'notifications', label: 'Notifications' },
  { key: 'events', label: 'Events' },
  { key: 'activities', label: 'Activities' },
  { key: 'growth', label: 'Growth & skills' },
  { key: 'stars', label: 'Stars' },
  { key: 'fees', label: 'Fees' },
  { key: 'bus_tracking', label: 'Bus tracking' },
]
