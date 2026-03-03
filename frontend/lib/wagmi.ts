import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { defineChain } from 'viem'

export const passetHub = defineChain({
  id: 420420417,
  name: 'Passet Hub',
  nativeCurrency: { name: 'PAS', symbol: 'PAS', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://eth-rpc-testnet.polkadot.io/'] },
  },
  blockExplorers: {
    default: {
      name: 'Blockscout',
      url: 'https://blockscout-testnet.polkadot.io',
    },
  },
  testnet: true,
})

export const wagmiConfig = getDefaultConfig({
  appName: 'ReviveUSD',
  projectId: 'reviveusd-demo',
  chains: [passetHub],
  ssr: true,
})
