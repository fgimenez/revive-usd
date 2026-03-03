'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { ConnectButton } from '@rainbow-me/rainbowkit'

const links = [
  { href: '/', label: 'Dashboard' },
  { href: '/vault', label: 'Vault' },
  { href: '/liquidations', label: 'Liquidations' },
]

export function Nav() {
  const pathname = usePathname()
  return (
    <header className="border-b border-gray-800 bg-gray-900">
      <div className="max-w-5xl mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-8">
          <span className="font-bold text-lg tracking-tight">
            Revive<span className="text-pink-400">USD</span>
          </span>
          <nav className="flex gap-6 text-sm">
            {links.map(({ href, label }) => (
              <Link
                key={href}
                href={href}
                className={pathname === href
                  ? 'text-white font-medium'
                  : 'text-gray-400 hover:text-white transition-colors'}
              >
                {label}
              </Link>
            ))}
          </nav>
        </div>
        <ConnectButton chainStatus="icon" showBalance={false} />
      </div>
    </header>
  )
}
