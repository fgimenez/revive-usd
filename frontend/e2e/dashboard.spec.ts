import { test, expect } from '@playwright/test'
import { mockRpc } from './helpers/mock-rpc'

test.beforeEach(async ({ page }) => {
  await mockRpc(page)
})

test('renders heading and description', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'ReviveUSD' })).toBeVisible()
  await expect(page.getByText('Lock native PAS, mint rUSD.')).toBeVisible()
})

test('shows oracle price from mock', async ({ page }) => {
  await page.goto('/')
  // Oracle.getPrice() mock returns 5e18 → $5.00
  await expect(page.getByText('$5.00')).toBeVisible()
})

test('shows rUSD supply stat card', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByText('rUSD Supply')).toBeVisible()
})

test('vault and liquidations action links present', async ({ page }) => {
  await page.goto('/')
  // Scope to <main> to avoid matching the nav links
  const main = page.getByRole('main')
  await expect(main.getByRole('link', { name: 'Open / Manage Vault' })).toBeVisible()
  await expect(main.getByRole('link', { name: 'Liquidations' })).toBeVisible()
})

test('shows contract addresses', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByText('0xe321098307B309bAab006e8600439a1c948f0860')).toBeVisible()
  await expect(page.getByText('0x5A2B2C4750c1034d39f30441642C8Be220F52618')).toBeVisible()
  await expect(page.getByText('0xA3cc725D53D69Aa5e570D73390c152f76F7BC0CE')).toBeVisible()
})
