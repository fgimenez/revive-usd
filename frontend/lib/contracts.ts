import { RUSD_ABI, ORACLE_ABI, VAULT_ABI } from './abis'

export const CONTRACTS = {
  RUSD: {
    address: '0xe321098307B309bAab006e8600439a1c948f0860' as `0x${string}`,
    abi: RUSD_ABI,
  },
  Oracle: {
    address: '0x5A2B2C4750c1034d39f30441642C8Be220F52618' as `0x${string}`,
    abi: ORACLE_ABI,
  },
  Vault: {
    address: '0xA3cc725D53D69Aa5e570D73390c152f76F7BC0CE' as `0x${string}`,
    abi: VAULT_ABI,
  },
} as const

export const EXPLORER = 'https://blockscout-testnet.polkadot.io'
