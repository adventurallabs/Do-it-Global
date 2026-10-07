export const HERO = {
  statement: 'Building technology for the way the world works.',
  sub: 'We design and engineer digital products — and the connected systems that keep them running.',
}

export const BUILD = {
  label: 'What we build',
  heading: 'Ideas, engineered\ninto systems people\nrely on every day.',
  body: 'We are a product company. We take a real-world problem, design the experience around the people living it, and build the whole thing — apps, platforms and the cloud underneath.',
  capabilities: [
    { title: 'Product design', text: 'Interfaces shaped around daily routines, not feature lists.' },
    { title: 'Mobile & web engineering', text: 'Native-quality apps in Flutter and on the web, built to last.' },
    { title: 'Connected systems', text: 'Real-time data that keeps everyone involved on the same page.' },
  ],
}

export type Product = {
  id: string
  label: string
  index: string
  name: string
  /** Wordmark on the portal card. */
  wordmark: string
  mark: { src: string; w: number; h: number }
  kicker: string
  /** Small print at the top right of the chapter. */
  note: string
  tagline: string
  path: string
  /** Light and rim colours of the portal card. */
  glow: string
  tint: string
  rim: 'violet' | 'nuvara'
  apps: { name: string; audience: string; features: string[]; accent: string; icon: string }[]
}

export const PRODUCT: Product = {
  id: 'product',
  label: 'Our products',
  index: '02',
  name: 'Palli',
  wordmark: 'PALLI',
  mark: { src: '/brand/palli-mark.webp', w: 40, h: 41 },
  kicker: 'Ecosystem',
  note: 'Our first product',
  tagline: 'A connected digital ecosystem for modern schools.',
  path: '/palli/',
  glow: '129,73,193',
  tint: '183,155,255',
  rim: 'violet',
  apps: [
    { name: 'PalliConnect', audience: 'Parents & students', features: ['Today', 'Homework', 'School bus'], accent: '#3EC6FF', icon: '/brand/palliconnect-icon.webp' },
    { name: 'PalliCore', audience: 'Teachers & administrators', features: ['Attendance', 'Timetable', 'Fees'], accent: '#E2C275', icon: '/brand/pallicore-icon.webp' },
  ],
}

export const NUVARA: Product = {
  id: 'nuvara',
  label: 'Our products',
  index: '03',
  name: 'Nuvara',
  wordmark: 'NUVARA',
  mark: { src: '/brand/nuvara-mark.webp', w: 36, h: 40 },
  kicker: 'Therapy centres',
  note: 'For therapy centres',
  tagline: 'Each therapy centre’s own app — for its therapists and every family.',
  path: '/nuvara/',
  glow: '234,80,30',
  tint: '54,169,224',
  rim: 'nuvara',
  apps: [
    { name: 'Centre & therapists', audience: 'Admin · Therapist', features: ['Timetable', 'Sessions', 'Fees'], accent: '#EA501E', icon: '/brand/nuvara-icon.webp' },
    { name: 'Families', audience: 'Parents', features: ['Schedule', 'Progress', 'UPI'], accent: '#36A9E0', icon: '/brand/nuvara-icon.webp' },
  ],
}

export const PRINCIPLES = [
  {
    title: 'Simple, first.',
    text: 'If someone needs a manual, we are not finished. Every screen has to earn its place in a busy day.',
  },
  {
    title: 'Connected by design.',
    text: 'One action, seen by everyone it concerns. Systems should talk to each other so people don’t have to chase.',
  },
  {
    title: 'Built for the real world.',
    text: 'Patchy networks, rushed mornings, more than one language. We design for the conditions people actually live in.',
  },
]

export const VISION = {
  label: 'Where we’re going',
  statement: 'Technology that connects people, organisations and the everyday systems between them.',
  sub: 'Palli and Nuvara are the first. The approach behind them is how we will build everything that follows.',
}
