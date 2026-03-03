'use client'

import { useState } from 'react'
import { useAccount, useReadContracts, useWriteContract, useWaitForTransactionReceipt, useBalance } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { CONTRACTS } from '@/lib/contracts'
import { RatioMeter } from '@/components/RatioMeter'

function Input({ label, value, onChange, placeholder, unit }: {
  label: string; value: string; onChange: (v: string) => void; placeholder: string; unit: string
}) {
  return (
    <div>
      <label className="text-sm text-gray-400 mb-1 block">{label}</label>
      <div className="flex items-center gap-2 bg-gray-800 rounded-lg px-3 py-2">
        <input
          type="number" min="0" step="any"
          value={value} onChange={e => onChange(e.target.value)}
          placeholder={placeholder}
          className="flex-1 bg-transparent outline-none text-sm"
        />
        <span className="text-gray-500 text-sm">{unit}</span>
      </div>
    </div>
  )
}

function ActionButton({ label, onClick, disabled, loading }: {
  label: string; onClick: () => void; disabled: boolean; loading: boolean
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled || loading}
      className="w-full py-2 rounded-lg bg-pink-500 hover:bg-pink-600 disabled:opacity-40 disabled:cursor-not-allowed transition-colors text-sm font-medium"
    >
      {loading ? 'Pending…' : label}
    </button>
  )
}

export default function VaultPage() {
  const { address } = useAccount()
  const [colInput, setColInput]   = useState('')
  const [debtInput, setDebtInput] = useState('')
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>()

  const { writeContract, isPending } = useWriteContract()
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash: txHash })

  const loading = isPending || isConfirming

  const { data: balance } = useBalance({ address })

  const { data, refetch } = useReadContracts({
    contracts: address ? [
      { ...CONTRACTS.Vault, functionName: 'positions',        args: [address] },
      { ...CONTRACTS.Vault, functionName: 'debtWithFee',      args: [address] },
      { ...CONTRACTS.Vault, functionName: 'collateralRatio',  args: [address] },
      { ...CONTRACTS.Vault, functionName: 'maxMintable',      args: [address] },
      { ...CONTRACTS.Oracle, functionName: 'getPrice' },
    ] : [],
  })

  const pos       = data?.[0]?.result as [bigint, bigint, bigint] | undefined
  const debtFee   = data?.[1]?.result as bigint | undefined
  const ratio     = data?.[2]?.result as bigint | undefined
  const maxMint   = data?.[3]?.result as bigint | undefined
  const price     = data?.[4]?.result as bigint | undefined

  const collateral = pos?.[0] ?? 0n
  const hasPos     = collateral > 0n

  const send = (fn: () => void) => {
    fn()
    setTimeout(refetch, 3000)
  }

  const open = () => send(() => writeContract({
    ...CONTRACTS.Vault, functionName: 'open',
    value: parseEther(colInput || '0'),
  }, { onSuccess: h => setTxHash(h) }))

  const deposit = () => send(() => writeContract({
    ...CONTRACTS.Vault, functionName: 'deposit',
    value: parseEther(colInput || '0'),
  }, { onSuccess: h => setTxHash(h) }))

  const withdraw = () => send(() => writeContract({
    ...CONTRACTS.Vault, functionName: 'withdraw',
    args: [parseEther(colInput || '0')],
  }, { onSuccess: h => setTxHash(h) }))

  const mint = () => send(() => writeContract({
    ...CONTRACTS.Vault, functionName: 'mint',
    args: [parseEther(debtInput || '0')],
  }, { onSuccess: h => setTxHash(h) }))

  const burn = () => send(() => writeContract({
    ...CONTRACTS.Vault, functionName: 'burn',
    args: [parseEther(debtInput || '0')],
  }, { onSuccess: h => setTxHash(h) }))

  const close = () => send(() => writeContract({
    ...CONTRACTS.Vault, functionName: 'close',
  }, { onSuccess: h => setTxHash(h) }))

  if (!address) {
    return (
      <div className="text-center py-24 text-gray-400">
        Connect your wallet to manage your vault.
      </div>
    )
  }

  const fmt = (v: bigint | undefined) =>
    v !== undefined ? parseFloat(formatEther(v)).toFixed(4) : '...'

  const ratioNum = ratio !== undefined
    ? (ratio > BigInt(10 ** 9) ? Infinity : Number(ratio))
    : null

  return (
    <div className="space-y-6 max-w-xl mx-auto">
      <h1 className="text-2xl font-bold">Your Vault</h1>

      {/* Position summary */}
      <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-4">
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <p className="text-gray-400">Collateral</p>
            <p className="text-lg font-semibold">{fmt(collateral)} PAS</p>
          </div>
          <div>
            <p className="text-gray-400">Debt (with fee)</p>
            <p className="text-lg font-semibold">{fmt(debtFee)} rUSD</p>
          </div>
          <div>
            <p className="text-gray-400">PAS price</p>
            <p className="text-lg font-semibold">${fmt(price)}</p>
          </div>
          <div>
            <p className="text-gray-400">Max mintable</p>
            <p className="text-lg font-semibold">{fmt(maxMint)} rUSD</p>
          </div>
        </div>
        <RatioMeter ratio={ratioNum} />
        <p className="text-xs text-gray-500">
          Wallet: {fmt(balance?.value)} PAS
        </p>
      </div>

      {/* Collateral actions */}
      <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-4">
        <h2 className="font-semibold">Collateral</h2>
        <Input label="Amount" value={colInput} onChange={setColInput} placeholder="0.0" unit="PAS" />
        <div className="grid grid-cols-3 gap-2">
          {!hasPos
            ? <ActionButton label="Open" onClick={open} disabled={!colInput} loading={loading} />
            : <>
                <ActionButton label="Deposit" onClick={deposit} disabled={!colInput} loading={loading} />
                <ActionButton label="Withdraw" onClick={withdraw} disabled={!colInput} loading={loading} />
                <ActionButton label="Close" onClick={close} disabled={debtFee !== 0n} loading={loading} />
              </>
          }
        </div>
      </div>

      {/* Debt actions */}
      {hasPos && (
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-4">
          <h2 className="font-semibold">Debt</h2>
          <Input label="Amount" value={debtInput} onChange={setDebtInput} placeholder="0.0" unit="rUSD" />
          <div className="grid grid-cols-2 gap-2">
            <ActionButton label="Mint rUSD" onClick={mint} disabled={!debtInput} loading={loading} />
            <ActionButton label="Burn rUSD" onClick={burn} disabled={!debtInput} loading={loading} />
          </div>
        </div>
      )}
    </div>
  )
}
