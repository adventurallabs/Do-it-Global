import { NV } from './kit'

/**
 * RatingChart from lib/widgets/charts.dart: progress on a fixed 0–10 scale,
 * one point per day joined by a 2px line, faint bands behind it for what the
 * numbers mean (needs support / developing / doing well), the latest day
 * ringed and labelled. `grow` (0–1) draws the line in, for scroll scenes.
 */
export function RatingChart({ points, color = NV.brand600, height = 170, grow = 1, from = '1 Jul', to = '6 Oct', width = 320 }: { points: number[]; color?: string; height?: number; grow?: number; from?: string; to?: string; width?: number }) {
  const l = 24, r = 30, t = 12, bt = 22
  const w = width - l - r
  const h = height - t - bt
  const x = (i: number) => l + (points.length === 1 ? w / 2 : (i / (points.length - 1)) * w)
  const y = (v: number) => t + h - (v / 10) * h
  const shown = Math.max(1, Math.round(grow * (points.length - 1)) + 1)
  const pts = points.slice(0, shown)
  const path = pts.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' ')
  const last = pts.length - 1
  const fmt = (v: number) => (Number.isInteger(v) ? String(v) : v.toFixed(1))
  return (
    <svg viewBox={`0 0 ${width} ${height}`} width="100%" aria-hidden className="block overflow-visible">
      {[
        [0, 4, NV.red],
        [4, 7, NV.amber],
        [7, 10, NV.green],
      ].map(([lo, hi, c]) => (
        <rect key={String(c)} x={l} y={y(hi as number)} width={w} height={y(lo as number) - y(hi as number)} fill={c as string} opacity={0.045} />
      ))}
      {[0, 5, 10].map((v) => (
        <g key={v}>
          <line x1={l} x2={l + w} y1={y(v)} y2={y(v)} stroke={NV.line} strokeWidth={1} />
          <text x={l - 6} y={y(v) + 3.5} textAnchor="end" fontSize={10} fontWeight={600} fill={NV.muted}>
            {v}
          </text>
        </g>
      ))}
      <path d={path} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
      {pts.slice(0, -1).map((v, i) => (
        <circle key={i} cx={x(i)} cy={y(v)} r={2.6} fill={color} />
      ))}
      <circle cx={x(last)} cy={y(pts[last])} r={5} fill="#fff" />
      <circle cx={x(last)} cy={y(pts[last])} r={4} fill={color} />
      <text x={x(last) + 9} y={y(pts[last]) + 4} fontSize={12} fontWeight={800} fill={NV.ink}>
        {fmt(pts[last])}
      </text>
      <text x={l} y={height - 4} fontSize={10} fontWeight={600} fill={NV.muted}>
        {from}
      </text>
      <text x={l + w} y={height - 4} textAnchor="end" fontSize={10} fontWeight={600} fill={NV.muted}>
        {to}
      </text>
    </svg>
  )
}
