import { RUSD_ABI, ORACLE_ABI, VAULT_ABI } from './abis'
import testnet from '../../deployments/testnet.json'

const deployments = { testnet } as const
type Network = keyof typeof deployments

const network = (process.env.NEXT_PUBLIC_NETWORK ?? 'testnet') as Network
const deployment = deployments[network] ?? deployments.testnet

export const CONTRACTS = {
  RUSD: {
    address: deployment.contracts.RUSD as `0x${string}`,
    abi: RUSD_ABI,
  },
  Oracle: {
    address: deployment.contracts.Oracle as `0x${string}`,
    abi: ORACLE_ABI,
  },
  Vault: {
    address: deployment.contracts.Vault as `0x${string}`,
    abi: VAULT_ABI,
  },
} as const

export const EXPLORER = deployment.explorer
