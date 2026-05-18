import { describe, it, expect } from "vitest";
import { submitCart } from "../../../../src/checkout/submit-cart";
import { authenticatedCustomerWithAddress, emptyCart } from "../../helpers";

describe("R-01 cart non-empty rule", () => {
  it("rejects submission when cart is empty", async () => {
    // Given an authenticated customer with a valid shipping address
    const customer = authenticatedCustomerWithAddress();
    // And an empty cart
    const cart = emptyCart(customer);

    // When the customer submits the cart
    const result = await submitCart({ customer, cart });

    // Then the submission is rejected with reason "EMPTY_CART"
    expect(result.status).toBe("rejected");
    expect(result.reason).toBe("EMPTY_CART");
    // And no order is created
    expect(result.orderId).toBeUndefined();
  });
});
