import { test, expect } from '@playwright/test';
import { templates } from '../src/templates/registry';

test.describe('Templates gallery', () => {
  test('lists all registered templates', async ({ page }) => {
    await page.goto('/templates');
    await expect(page.getByRole('heading', { name: 'Choose Your Template' })).toBeVisible();
    for (const t of templates) {
      await expect(page.getByRole('heading', { name: t.name, level: 3 })).toBeVisible();
    }
  });
});
