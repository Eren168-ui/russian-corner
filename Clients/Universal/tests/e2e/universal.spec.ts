import { expect, test } from '@playwright/test'

const viewports = [
  { width: 360, height: 800 },
  { width: 390, height: 844 },
  { width: 768, height: 1024 },
  { width: 1366, height: 768 },
]

test('fits every approved viewport with accessible controls', async ({ page }) => {
  for (const viewport of viewports) {
    await page.setViewportSize(viewport)
    await page.goto('/')
    await expect(page.getByText('LANGUAGE CORNER', { exact: true })).toBeVisible()
    const metrics = await page.evaluate(() => ({
      viewport: window.innerWidth,
      page: document.documentElement.scrollWidth,
      bodyFont: Number.parseFloat(getComputedStyle(document.body).fontSize),
      shortControls: [...document.querySelectorAll('button, select')].filter((element) => element.getBoundingClientRect().height < 44).length,
    }))
    expect(metrics.page).toBeLessThanOrEqual(metrics.viewport)
    expect(metrics.bodyFont).toBeGreaterThanOrEqual(16)
    expect(metrics.shortControls).toBe(0)
  }

  await page.setViewportSize({ width: 360, height: 800 })
  await page.getByRole('button', { name: '开始今天练习' }).click()
  await expect(page.getByText('1 / 3')).toBeVisible()
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)

  await page.keyboard.press('Tab')
  const focused = page.locator(':focus')
  await expect(focused).toBeVisible()
  expect(await focused.evaluate((element) => getComputedStyle(element).outlineStyle)).not.toBe('none')

  await page.emulateMedia({ reducedMotion: 'reduce' })
  const reducedDuration = await page.locator('.three-second span').evaluate((element) => Number.parseFloat(getComputedStyle(element, '::after').animationDuration))
  expect(reducedDuration).toBeLessThan(0.001)
})

test('keeps the real learning shell and content usable after going offline', async ({ page, context }) => {
  await page.goto('/')
  await page.evaluate(() => navigator.serviceWorker.ready)
  await page.reload()
  await expect(page.getByText('LANGUAGE CORNER', { exact: true })).toBeVisible()

  await context.setOffline(true)
  await page.reload()
  await expect(page.getByText('LANGUAGE CORNER', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: '开始今天练习' }).click()
  await expect(page.getByText('1 / 3')).toBeVisible()
  await expect(page.locator('body')).not.toContainText(/PWA|Tauri|Capacitor|Flutter|service worker|runtime|schema/i)
})
