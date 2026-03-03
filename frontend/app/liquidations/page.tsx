'use client'

import { useReadContracts, useWriteContract, useWaitForTransactionReceipt, usePublicClient } from 'wagmi'
import { formatEther } from 'viem'
import { useState, useEffect } from 'react'
import { CONTRACTS, EXPLORER } from '@/lib/contracts'

type Position = {
  address: `0x${string}`
  collateral: bigint
  debt: bigint
  ratio: bigint
}

export default function LiquidationsPage() {
  const [candidates, setCandidates] = useState<Position[]>([])
  const [loading, setLoading] = useState(false)
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>()
  const client = usePublicClient()

  const { writeContract, isPending } = useWriteContract()
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash: txHash })

  useEffect(() => {
    if (!client) return
    setLoading(true)

    // Scan Opened events to get all vault users
    client.getLogs({
      address: CONTRACTS.Vault.address,
      event: {
        type: 'event',
        name: 'Opened',
        inputs: [
          { type: 'address', name: 'user', indexed: true },
          { type: 'uint256', name: 'collateral' },
        ],
      },
      fromBlock: 0n,
    }).then(async (logs) => {
      const users = [...new Set(logs.map(l => l.args.user as `0x${string}`))]

      const results = await client.multicall({
        contracts: users.flatMap(u => [
          { ...CONTRACTS.Vault, functionName: 'positions'       as const, args: [u] },
          { ...CONTRACTS.Vault, functionName: 'collateralRatio' as const, args: [u] },
          { ...CONTRACTS.Vault, functionName: 'debtWithFee'     as const, args: [u] },
        ]),
      })

      const positions: Position[] = []
      for (let i = 0; i < users.length; i++) {
        const pos   = results[i * 3]?.result as [bigint, bigint, bigint] | undefined
        const ratio = results[i * 3 + 1]?.result as bigint | undefined
        const debt  = results[i * 3 + 2]?.result as bigint | undefined
        if (!pos || pos[0] === 0n) continue
        if (ratio !== undefined && ratio < 130n) {
          positions.push({ address: users[i], collateral: pos[0], debt: debt ?? 0n, ratio })
        }
      }
      setCandidates(positions)
    }).finally(() => setLoading(false))
  }, [client])

  const liquidate = (user: `0x${string}`) => {
    writeContract(
      { ...CONTRACTS.Vault, functionName: 'liquidate', args: [user] },
      { onSuccess: h => setTxHash(h) }
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Liquidations</h1>
        <p className="text-gray-400 text-sm mt-1">
          Positions below 130% collateral ratio. Burn their debt, receive their collateral.
        </p>
      </div>

      {loading && <p className="text-gray-400">Scanning vault positions…</p>}

      {!loading && candidates.length === 0 && (
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-8 text-center text-gray-400">
          No liquidatable positions right now.
        </div>
      )}

      {candidates.length > 0 && (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-gray-400 border-b border-gray-800">
                <th className="text-left py-3 pr-4">Address</th>
                <th className="text-right py-3 pr-4">Collateral</th>
                <th className="text-right py-3 pr-4">Debt</th>
                <th className="text-right py-3 pr-4">Ratio</th>
                <th className="py-3" />
              </tr>
            </thead>
            <tbody>
              {candidates.map(pos => (
                <tr key={pos.address} className="border-b border-gray-900 hover:bg-gray-900/50">
                  <td className="py-3 pr-4 font-mono text-xs">
                    <a href={`${EXPLORER}/address/${pos.address}`} target="_blank" rel="noreferrer"
                      className="text-pink-400 hover:underline">
                      {pos.address.slice(0, 8)}…{pos.address.slice(-6)}
                    </a>
                  </td>
                  <td className="text-right py-3 pr-4">{parseFloat(formatEther(pos.collateral)).toFixed(2)} PAS</td>
                  <td className="text-right py-3 pr-4">{parseFloat(formatEther(pos.debt)).toFixed(2)} rUSD</td>
                  <td className="text-right py-3 pr-4 text-red-400 font-semibold">{pos.ratio.toString()}%</td>
                  <td className="py-3 pl-4">
                    <button
                      onClick={() => liquidate(pos.address)}
                      disabled={isPending || isConfirming}
                      className="px-3 py-1 rounded-lg bg-red-600 hover:bg-red-700 disabled:opacity-40 text-xs font-medium transition-colors"
                    >
                      {isPending || isConfirming ? 'Pending…' : 'Liquidate'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
