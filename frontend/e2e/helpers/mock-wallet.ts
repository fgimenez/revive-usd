import type { Page } from '@playwright/test'

const CHAIN_ID_HEX = '0x18fb9e01' // 420420417

/**
 * Injects a minimal EIP-1193 window.ethereum mock + EIP-6963 MIPD announcement
 * before the page boots.
 *
 * wagmi's SSR config creates an MIPD store (mipd) and dispatches
 * `eip6963:requestProvider` on startup.  Our script listens for that event and
 * responds with an `eip6963:announceProvider` event.  wagmi's onMount() reads
 * the MIPD store, creates a *targeted* injected connector for our provider,
 * and calls reconnect() — which calls eth_accounts, gets our address, and
 * marks the session connected without any localStorage tricks.
 */
export async function injectWallet(page: Page, address: string) {
  await page.addInitScript((addr: string) => {
    const listeners: Record<string, Array<(...args: unknown[]) => void>> = {}

    const provider = {
      isMetaMask: true,
      selectedAddress: addr,
      chainId: '0x18fb9e01',
      request: async ({ method }: { method: string }) => {
        if (method === 'eth_requestAccounts' || method === 'eth_accounts') return [addr]
        if (method === 'eth_chainId') return '0x18fb9e01'
        if (method === 'net_version') return '420420417'
        if (method === 'wallet_switchEthereumChain') return null
        if (method === 'wallet_addEthereumChain') return null
        return null
      },
      on: (event: string, handler: (...args: unknown[]) => void) => {
        ;(listeners[event] ??= []).push(handler)
      },
      removeListener: (event: string, handler: (...args: unknown[]) => void) => {
        listeners[event] = (listeners[event] ?? []).filter(h => h !== handler)
      },
    }

    // Also expose as window.ethereum for any direct checks
    ;(window as Window & { ethereum?: unknown }).ethereum = provider

    // EIP-6963: announce ourselves as a wallet provider.
    // wagmi creates a targeted injected connector from any MIPD provider.
    const providerDetail = Object.freeze({
      info: Object.freeze({
        uuid: 'e2e-test-wallet-uuid',
        name: 'E2E Test Wallet',
        icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg"/>',
        rdns: 'com.e2e.testwallet',
      }),
      provider,
    })

    function announce() {
      window.dispatchEvent(
        new CustomEvent('eip6963:announceProvider', { detail: providerDetail }),
      )
    }

    // Announce immediately (for any listener already active)
    announce()

    // Re-announce whenever wagmi's MIPD store requests providers
    window.addEventListener('eip6963:requestProvider', announce)
  }, address)
}

/**
 * Pre-seeds wagmi's localStorage state so the page auto-reconnects with the
 * given address on load without requiring a click through the RainbowKit modal.
 *
 * wagmi v3 serialises its connection Map as { __type: 'Map', value: [...] }.
 * `version` must match wagmi's package major (3) or migrate() discards the state.
 *
 * NOTE: This is optional when used alongside injectWallet() — the EIP-6963
 * announce flow handles reconnect by itself.  Use this if you need to guarantee
 * a specific connector UID shows up in state.connections before onMount fires.
 */
export async function setWagmiConnected(page: Page, address: string) {
  await page.addInitScript(
    ({ addr, chainIdHex }: { addr: string; chainIdHex: string }) => {
      const chainId = parseInt(chainIdHex, 16)
      const connectorUid = 'com.e2e.testwallet'
      const store = {
        state: {
          chainId,
          connections: {
            __type: 'Map',
            value: [
              [
                connectorUid,
                {
                  accounts: [addr],
                  chainId,
                  connector: {
                    id: connectorUid,
                    name: 'E2E Test Wallet',
                    type: 'injected',
                    uid: connectorUid,
                  },
                },
              ],
            ],
          },
          current: connectorUid,
        },
        version: 3, // must match wagmi's package major version
      }
      localStorage.setItem('wagmi.store', JSON.stringify(store))
      // Required for targetless injected connector's isAuthorized() check
      localStorage.setItem('wagmi.injected.connected', 'true')
      localStorage.setItem('wagmi.recentConnectorId', JSON.stringify(connectorUid))
    },
    { addr: address, chainIdHex: CHAIN_ID_HEX },
  )
}
