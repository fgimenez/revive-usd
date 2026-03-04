import { test, expect } from '@playwright/test'
import { mockRpc } from './helpers/mock-rpc'

test.beforeEach(async ({ page }) => {
  await mockRpc(page)
})

test('dashboard link is active on /', async ({ page }) => {
  await page.goto('/')
  // Scope to <nav> to avoid matching the action-card links in <main>
  const nav = page.getByRole('navigation')
  await expect(nav.getByRole('link', { name: 'Dashboard' })).toHaveClass(/text-white/)
  await expect(nav.getByRole('link', { name: 'Vault' })).toHaveClass(/text-gray-400/)
})

test('vault link is active on /vault', async ({ page }) => {
  await page.goto('/vault')
  const nav = page.getByRole('navigation')
  await expect(nav.getByRole('link', { name: 'Vault' })).toHaveClass(/text-white/)
  await expect(nav.getByRole('link', { name: 'Dashboard' })).toHaveClass(/text-gray-400/)
})

test('liquidations link is active on /liquidations', async ({ page }) => {
  await page.goto('/liquidations')
  const nav = page.getByRole('navigation')
  await expect(nav.getByRole('link', { name: 'Liquidations' })).toHaveClass(/text-white/)
  await expect(nav.getByRole('link', { name: 'Dashboard' })).toHaveClass(/text-gray-400/)
})

test('clicking vault link navigates to /vault', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('navigation').getByRole('link', { name: 'Vault' }).click()
  await expect(page).toHaveURL('/vault')
})

test('clicking liquidations link navigates to /liquidations', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('navigation').getByRole('link', { name: 'Liquidations' }).click()
  await expect(page).toHaveURL('/liquidations')
})

test('liquidations page shows empty state with mock', async ({ page }) => {
  await page.goto('/liquidations')
  await expect(page.getByRole('heading', { name: 'Liquidations' })).toBeVisible()
  // getLogs mock returns [] → no candidates → empty state message
  await expect(page.getByText('No liquidatable positions right now.')).toBeVisible({ timeout: 10_000 })
})
