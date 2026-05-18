import { describe, it, expect, vi } from "vitest";
import { submitCart } from "../../../../src/checkout/submit-cart";

describe("R-05 declined card", () => {
  it("rejects when card is declined", async () => {
    // Bad pattern #1: mocks the system under test itself.
    const fakeSubmit = vi.fn().mockResolvedValue({ status: "rejected" });
    (submitCart as unknown as { _impl: unknown })._impl = fakeSubmit;

    // Bad pattern #2: drops concrete scenario data (no 39.98 EUR, no two items).
    const result = await fakeSubmit();

    // Bad pattern #3: assertion is weaker than the scenario states
    // (scenario requires reason "PAYMENT_DECLINED" + cart untouched).
    expect(result).toBeTruthy();
  });
});
