'use client'

const LIQ = 130
const MIN = 150

export function RatioMeter({ ratio }: { ratio: number | null }) {
  if (ratio === null) {
    return (
      <div className="space-y-1">
        <p className="text-sm text-gray-400">Collateral Ratio</p>
        <div className="h-3 bg-gray-800 rounded-full" />
      </div>
    )
  }

  const isInfinite = !isFinite(ratio)
  const display = isInfinite ? '∞' : `${ratio.toFixed(0)}%`
  const color = isInfinite || ratio >= MIN
    ? 'bg-green-500'
    : ratio >= LIQ
    ? 'bg-yellow-500'
    : 'bg-red-500'

  // Cap bar at 300% for display
  const pct = isInfinite ? 100 : Math.min(ratio / 300 * 100, 100)

  return (
    <div className="space-y-1">
      <div className="flex justify-between text-sm">
        <span className="text-gray-400">Collateral Ratio</span>
        <span className={`font-semibold ${isInfinite || ratio >= MIN ? 'text-green-400' : ratio >= LIQ ? 'text-yellow-400' : 'text-red-400'}`}>
          {display}
        </span>
      </div>
      <div className="h-3 bg-gray-800 rounded-full overflow-hidden">
        <div className={`h-full rounded-full transition-all ${color}`} style={{ width: `${pct}%` }} />
      </div>
      <div className="flex justify-between text-xs text-gray-600">
        <span>Liq {LIQ}%</span>
        <span>Min {MIN}%</span>
      </div>
    </div>
  )
}
