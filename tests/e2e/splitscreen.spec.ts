import { test, expect } from "@playwright/test";

const BASE = process.env.SZTAUER_URL || "http://localhost:420";

test.describe("Split screen", () => {
  test("loads with two iframes", async ({ page }) => {
    await page.goto(`${BASE}/sztauer`);
    const iframes = page.locator("iframe");
    await expect(iframes).toHaveCount(2);
  });

  test("iframes have correct sources", async ({ page }) => {
    await page.goto(`${BASE}/sztauer`);
    const iframes = page.locator("iframe");
    const srcs = await iframes.evaluateAll((els) =>
      els.map((el) => el.getAttribute("src"))
    );
    expect(srcs).toContain("/sztauer/editor/");
    expect(srcs).toContain("/sztauer/terminal/");
  });

  test("layout is 50/50 grid", async ({ page }) => {
    await page.goto(`${BASE}/sztauer`);
    const split = page.locator(".split");
    const style = await split.evaluate((el) => getComputedStyle(el));
    expect(style.display).toBe("grid");

    // Both iframes should be approximately half the viewport
    const iframes = page.locator("iframe");
    const boxes = await iframes.evaluateAll((els) =>
      els.map((el) => el.getBoundingClientRect())
    );
    expect(boxes).toHaveLength(2);

    const viewportWidth = page.viewportSize()?.width || 1280;
    const halfWidth = viewportWidth / 2;
    const tolerance = 10;

    for (const box of boxes) {
      expect(box.width).toBeGreaterThan(halfWidth - tolerance);
      expect(box.width).toBeLessThan(halfWidth + tolerance);
    }
  });

  test("iframes fill viewport height", async ({ page }) => {
    await page.goto(`${BASE}/sztauer`);
    const viewportHeight = page.viewportSize()?.height || 720;
    const iframes = page.locator("iframe");
    const heights = await iframes.evaluateAll((els) =>
      els.map((el) => el.getBoundingClientRect().height)
    );
    for (const h of heights) {
      expect(h).toBeGreaterThanOrEqual(viewportHeight - 5);
    }
  });
});
