'use client'

import { useReadContracts } from 'wagmi'
import { formatEther } from 'viem'
import { CONTRACTS, EXPLORER } from '@/lib/contracts'
import Link from 'next/link'

function StatCard({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
      <p className="text-sm text-gray-400 mb-1">{label}</p>
      <p className="text-2xl font-semibold">{value}</p>
      {sub && <p className="text-xs text-gray-500 mt-1">{sub}</p>}
    </div>
  )
}

export default function Dashboard() {
  const { data } = useReadContracts({
    contracts: [
      { ...CONTRACTS.Oracle, functionName: 'getPrice' },
      { ...CONTRACTS.RUSD,   functionName: 'totalSupply' },
      { ...CONTRACTS.Vault,  functionName: 'feeAccumulator' },
    ],
  })

  const price       = data?.[0]?.result as bigint | undefined
  const supply      = data?.[1]?.result as bigint | undefined
  const accumulator = data?.[2]?.result as bigint | undefined

  const priceUsd  = price       ? `$${parseFloat(formatEther(price)).toFixed(2)}` : '...'
  const supplyFmt = supply      ? `${parseFloat(formatEther(supply)).toLocaleString(undefined, { maximumFractionDigits: 2 })} rUSD` : '...'
  const feeRate   = accumulator ? `${((Number(accumulator) / 1e27 - 1) * 100).toFixed(4)}%` : '...'

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-1">ReviveUSD</h1>
        <p className="text-gray-400">
          CDP stablecoin on{' '}
          <a href={`${EXPLORER}/address/${CONTRACTS.Vault.address}`} target="_blank" rel="noreferrer"
            className="text-pink-400 hover:underline">Polkadot Hub</a>.
          Lock native PAS, mint rUSD.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard label="PAS / USD" value={priceUsd} sub="Oracle price" />
        <StatCard label="rUSD Supply" value={supplyFmt} sub="Total minted" />
        <StatCard label="Accrued Fee" value={feeRate} sub="Since deployment (~5% APY)" />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Link href="/vault"
          className="block bg-pink-500 hover:bg-pink-600 transition-colors rounded-xl p-6 text-center font-semibold text-lg">
          Open / Manage Vault
        </Link>
        <Link href="/liquidations"
          className="block bg-gray-800 hover:bg-gray-700 transition-colors rounded-xl p-6 text-center font-semibold text-lg">
          Liquidations
        </Link>
      </div>

      <div className="text-xs text-gray-600 space-y-1 font-mono">
        <p>RUSD:   <a href={`${EXPLORER}/address/${CONTRACTS.RUSD.address}`} target="_blank" rel="noreferrer" className="hover:text-gray-400">{CONTRACTS.RUSD.address}</a></p>
        <p>Oracle: <a href={`${EXPLORER}/address/${CONTRACTS.Oracle.address}`} target="_blank" rel="noreferrer" className="hover:text-gray-400">{CONTRACTS.Oracle.address}</a></p>
        <p>Vault:  <a href={`${EXPLORER}/address/${CONTRACTS.Vault.address}`} target="_blank" rel="noreferrer" className="hover:text-gray-400">{CONTRACTS.Vault.address}</a></p>
      </div>
    </div>
  )
}
