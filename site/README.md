# Do It Global Technologies — website

Static pages built with React + Vite + TypeScript, Three.js / React Three Fiber, GSAP ScrollTrigger, Lenis and Tailwind v4.

| URL | Entry | What it is |
| --- | --- | --- |
| `/` | `index.html` → `src/entries/company.tsx` | Company landing page |
| `/palli/` | `palli/index.html` → `src/entries/palli.tsx` | Palli product experience (opened in a new tab from the company page) |
| `/nuvara/` | `nuvara/index.html` → `src/entries/nuvara.tsx` | Nuvara product experience (opened in a new tab from the company page) |

## Develop

```bash
npm install
npm run dev            # http://localhost:5173, /palli/ and /nuvara/
npm run build          # typecheck + static build into dist/
npm run preview
```

`/preview.html?k=phone` and `?k=tablet` (dev only, not built) show every recreated Palli screen on one sheet; `?k=nv-phone` and `?k=nv-tablet` show the Nuvara ones.

## Deploy to Cloudflare Pages

- Build command: `npm run build`
- Output directory: `dist`
- Environment variable: `VITE_SITE_URL=https://your-domain` (used for canonical and Open Graph URLs)

No server code is involved. `public/_headers` sets long-lived caching for hashed assets.

## Before launch

- Replace the placeholder contact details and social links in `src/data/site.ts`. The email uses the reserved `.example` domain, so it can never reach anyone by accident.
- Set `VITE_SITE_URL` to the real domain.

## How it is put together

```
src/
  pages/        CompanyPage, PalliPage, NuvaraPage
  sections/     company/*, palli/*, nuvara/*  (page chapters)
  components/   DeviceFrame, DeviceStory, RevealText, MagneticButton, Nav, SceneCanvas, …
  three/        company/ (morphing point field), palli/ (core, orbits, role network, bus world), nuvara/ (scene reusing palli's core, orbits and role network), common/
  screens/      connect/*, core/*, nuvara/*  (HTML recreations of the Flutter apps' screens)
  lib/          scroll store, quality tiers, blending helpers
  hooks/        scroll director (Lenis + ScrollTrigger), section registration, media queries
  data/         copy, sample data, bus route
```

- **Scroll → 3D:** sections register with `useSection(id)`. A single GSAP ticker measures each section's share of the viewport into a mutable store (`lib/scrollStore.ts`), and each scene blends its per-chapter looks by those weights. Scrolling never re-renders React.
- **Shaders:** always create `ShaderMaterial`s with `three/common/useShader.ts`. Passing `uniforms` as a JSX prop copies the uniform wrappers, which freezes primitive uniforms.
- **App screens:** recreated in HTML/CSS from the PalliConnect and PalliCore Flutter sources (design tokens, widget structure, English and Tamil strings). All data shown is illustrative sample data (`data/sample.ts`). The page footer says so.
- **Nuvara screens:** recreated from the Nuvara Flutter source (`lib/theme.dart`, `lib/widgets/ui.dart`, `lib/widgets/shell.dart` and the parent / therapist / admin / assessment screens): Archivo + Plus Jakarta Sans, the navy / orange / sky palette, the bottom NavigationBar on phones and NavigationRail on tablets (container queries switch them at 700px of screen). The mark in `screens/nuvara/mark.ts` and `public/brand/nuvara-*` are generated from the vector trace in `lib/widgets/brand.dart`. Sample data lives in `data/nuvaraSample.ts`.
- **Performance:** WebGL loads lazily after first paint. Particle counts and DPR follow a device tier (`lib/quality.ts`), and `PerformanceMonitor` lowers DPR if the frame rate drops.
- **Reduced motion:** no smooth scrolling and no pinning. Chapters render as static layouts, and the 3D is a single still frame that fades out after the hero.
