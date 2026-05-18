# Rule: R-05 — Payment authorization is captured synchronously;
# a declined card rejects the submission and leaves the cart untouched.

Feature: Synchronous payment authorization at checkout

  @nominal @e2e
  Scenario: Authorized card creates the order and clears the cart
    Given an authenticated customer with a valid shipping address
    And a cart containing 2 items totalling 39.98 EUR
    And the customer's card "VISA-AUTH-OK" authorizes successfully for 39.98 EUR
    When the customer submits the cart
    Then the submission is accepted
    And an order is created with total 39.98 EUR
    And the cart becomes empty

  @violation @e2e
  Scenario: Declined card rejects submission and preserves the cart
    Given an authenticated customer with a valid shipping address
    And a cart containing 2 items totalling 39.98 EUR
    And the customer's card "VISA-DECLINED" is declined by the issuer
    When the customer submits the cart
    Then the submission is rejected with reason "PAYMENT_DECLINED"
    And no order is created
    And the cart still contains the same 2 items totalling 39.98 EUR

  @technical @e2e
  Scenario: Payment gateway timeout rejects submission and preserves the cart
    Given an authenticated customer with a valid shipping address
    And a cart containing 2 items totalling 39.98 EUR
    And the payment gateway does not respond within 5 seconds
    When the customer submits the cart
    Then the submission is rejected with reason "PAYMENT_TIMEOUT"
    And no order is created
    And the cart still contains the same 2 items totalling 39.98 EUR
