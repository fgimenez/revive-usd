import type { Page, Route } from '@playwright/test'

const RPC_URL = 'https://eth-rpc-testnet.polkadot.io/'

// Contract addresses (lowercase for comparison)
const ORACLE = '0x5a2b2c4750c1034d39f30441642c8be220f52618'
const RUSD   = '0xe321098307b309baab006e8600439a1c948f0860'
const VAULT  = '0xa3cc725d53d69aa5e570d73390c152f76f7bc0ce'

// Function selectors
const SEL = {
  getPrice:        '0x98d5fdca',
  totalSupply:     '0x18160ddd',
  feeAccumulator:  '0x5eaea35f',
  positions:       '0x55f57510',
  debtWithFee:     '0x6fe34862',
  collateralRatio: '0xca40742c',
  maxMintable:     '0x5ed88ecf',
} as const

// ABI-encoded return values
const RES = {
  getPrice:        '0x0000000000000000000000000000000000000000000000004563918244f40000',
  totalSupply:     '0x0000000000000000000000000000000000000000000000000000000000000000',
  feeAccumulator:  '0x0000000000000000000000000000000000000000033b2e3c9fd0803ce8000000',
  positions:       '0x0000000000000000000000000000000000000000000000000de0b6b3a7640000' +
                   '0000000000000000000000000000000000000000000000000429d069189e0000' +
                   '0000000000000000000000000000000000000000033b2e3c9fd0803ce8000000',
  debtWithFee:     '0x0000000000000000000000000000000000000000000000000429d069189e0000',
  collateralRatio: '0x0000000000000000000000000000000000000000000000056bc75e2d63100000',
  maxMintable:     '0x00000000000000000000000000000000000000000000000029a2241af62c0000',
} as const

function matchEthCall(body: { method: string; params?: unknown[] }, to: string, selector: string): boolean {
  if (body.method !== 'eth_call') return false
  const params = body.params as Array<{ to?: string; data?: string }>
  if (!params?.[0]) return false
  return (
    params[0].to?.toLowerCase() === to &&
    (params[0].data ?? '').toLowerCase().startsWith(selector)
  )
}

function jsonRpc(id: unknown, result: unknown) {
  return { jsonrpc: '2.0', id, result }
}

export async function mockRpc(page: Page) {
  // When REAL_RPC=1 let requests through to the live testnet (used by test:e2e:testnet)
  if (process.env.REAL_RPC) return

  await page.route(RPC_URL, async (route: Route) => {
    const body = route.request().postDataJSON() as { method: string; id: unknown; params?: unknown[] }
    const { method, id } = body

    if (method === 'eth_chainId')    return route.fulfill({ json: jsonRpc(id, '0x18fb9e01') })
    if (method === 'eth_blockNumber') return route.fulfill({ json: jsonRpc(id, '0x5b5503') })
    if (method === 'eth_getBalance')  return route.fulfill({ json: jsonRpc(id, '0xde0b6b3a7640000') })
    if (method === 'eth_getLogs')     return route.fulfill({ json: jsonRpc(id, []) })

    if (matchEthCall(body, ORACLE, SEL.getPrice))        return route.fulfill({ json: jsonRpc(id, RES.getPrice) })
    if (matchEthCall(body, RUSD,   SEL.totalSupply))     return route.fulfill({ json: jsonRpc(id, RES.totalSupply) })
    if (matchEthCall(body, VAULT,  SEL.feeAccumulator))  return route.fulfill({ json: jsonRpc(id, RES.feeAccumulator) })
    if (matchEthCall(body, VAULT,  SEL.positions))       return route.fulfill({ json: jsonRpc(id, RES.positions) })
    if (matchEthCall(body, VAULT,  SEL.debtWithFee))     return route.fulfill({ json: jsonRpc(id, RES.debtWithFee) })
    if (matchEthCall(body, VAULT,  SEL.collateralRatio)) return route.fulfill({ json: jsonRpc(id, RES.collateralRatio) })
    if (matchEthCall(body, VAULT,  SEL.maxMintable))     return route.fulfill({ json: jsonRpc(id, RES.maxMintable) })

    // Fallthrough: return empty result for anything else (e.g. eth_call to unknown selector)
    return route.fulfill({ json: jsonRpc(id, '0x') })
  })
}
