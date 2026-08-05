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
    await expect(page.getByRole('button', { name: 'Language Corner 今日练习' })).toBeVisible()
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
  await page.getByRole('button', { name: '查看安装方法' }).click()
  await expect(page.getByText('iPhone：')).toBeVisible()
  await page.getByRole('button', { name: '开始今天练习' }).click()
  await expect(page.locator('.counter')).toHaveText('1 / 8')
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
  await expect(page.getByRole('button', { name: 'Language Corner 今日练习' })).toBeVisible()

  await context.setOffline(true)
  await page.reload()
  await expect(page.getByRole('button', { name: 'Language Corner 今日练习' })).toBeVisible()
  await page.getByRole('button', { name: '开始今天练习' }).click()
  await expect(page.locator('.counter')).toHaveText('1 / 8')
  await expect(page.locator('body')).not.toContainText(/PWA|Tauri|Capacitor|Flutter|service worker|runtime|schema/i)
})

test('keeps functional pages compact with clear navigation and language switching', async ({ page }) => {
  await page.setViewportSize({ width: 1366, height: 900 })
  await page.goto('/')
  await page.getByRole('button', { name: '能力检测' }).click()

  const titleSize = await page.locator('.workspace-title h1').evaluate((element) => Number.parseFloat(getComputedStyle(element).fontSize))
  expect(titleSize).toBeLessThanOrEqual(42)
  await expect(page.getByRole('button', { name: '切换到英语' })).toBeVisible()
  await expect(page.getByRole('button', { name: '切换到俄语' })).toBeVisible()

  const navigationGap = await page.locator('.web-nav').evaluate((element) => Number.parseFloat(getComputedStyle(element).gap))
  expect(navigationGap).toBeGreaterThanOrEqual(6)
  const card = page.locator('.diagnosis-intro')
  expect((await card.boundingBox())!.height).toBeLessThanOrEqual(360)
})
