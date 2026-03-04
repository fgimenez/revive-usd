import { test, expect } from '@playwright/test'
import { mockRpc } from './helpers/mock-rpc'
import { injectWallet, setWagmiConnected } from './helpers/mock-wallet'

const TEST_ADDRESS = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'

// Always intercept RPC — no test should hit the real testnet
test.beforeEach(async ({ page }) => {
  await mockRpc(page)
})

test('unconnected: shows connect wallet message', async ({ page }) => {
  await page.goto('/vault')
  await expect(page.getByText('Connect your wallet to manage your vault.')).toBeVisible()
})

test('connected: shows Your Vault heading', async ({ page }) => {
  await injectWallet(page, TEST_ADDRESS)
  await setWagmiConnected(page, TEST_ADDRESS)
  await page.goto('/vault')
  await expect(page.getByRole('heading', { name: 'Your Vault' })).toBeVisible({ timeout: 10_000 })
})

test('connected: shows collateral and debt stat cards', async ({ page }) => {
  await injectWallet(page, TEST_ADDRESS)
  await setWagmiConnected(page, TEST_ADDRESS)
  await page.goto('/vault')
  await expect(page.getByRole('heading', { name: 'Your Vault' })).toBeVisible({ timeout: 10_000 })
  await expect(page.getByText('Collateral', { exact: true }).first()).toBeVisible()
  await expect(page.getByText('Debt (with fee)')).toBeVisible()
  await expect(page.getByText('PAS price')).toBeVisible()
  await expect(page.getByText('Max mintable')).toBeVisible()
})

test('connected with position: shows Debt section with Mint/Burn buttons', async ({ page }) => {
  test.skip(!!process.env.REAL_RPC, 'depends on mock positions() returning collateral > 0')
  // mock returns positions(addr) = (1e18, 3e17, 1e27) → collateral=1e18 > 0 → hasPos=true
  await injectWallet(page, TEST_ADDRESS)
  await setWagmiConnected(page, TEST_ADDRESS)
  await page.goto('/vault')
  await expect(page.getByRole('heading', { name: 'Your Vault' })).toBeVisible({ timeout: 10_000 })
  // Debt section renders only when hasPos=true
  await expect(page.getByRole('heading', { name: 'Debt' })).toBeVisible({ timeout: 10_000 })
  await expect(page.getByRole('button', { name: 'Mint rUSD' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Burn rUSD' })).toBeVisible()
})

test('connected with position: shows Deposit/Withdraw/Close buttons', async ({ page }) => {
  test.skip(!!process.env.REAL_RPC, 'depends on mock positions() returning collateral > 0')
  await injectWallet(page, TEST_ADDRESS)
  await setWagmiConnected(page, TEST_ADDRESS)
  await page.goto('/vault')
  await expect(page.getByRole('heading', { name: 'Your Vault' })).toBeVisible({ timeout: 10_000 })
  // hasPos=true → existing position buttons (not Open)
  await expect(page.getByRole('button', { name: 'Deposit' })).toBeVisible({ timeout: 10_000 })
  await expect(page.getByRole('button', { name: 'Withdraw' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Close' })).toBeVisible()
})
